#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange) 
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.

#require 'debugger'
require 'rubygems'
require 'sinatra/base'
require 'bundler/setup'
require 'pg'
require 'sass'
require 'erb'
require 'uri'
require 'money'
require "addressable/uri"
require 'pony'
require 'ir_b'
require 'monitor' # used for managing potentially recursive mutexes on Class singletons

Dir["./lib/*.rb"].each { |f| require f }
Dir["./lib/services/*.rb"].each { |f| require f }
Dir["./lib/query/*.rb"].each { |f| require f }
Dir["./lib/import/*.rb"].each { |f| require f }
Dir["./lib/churn_presenters/*.rb"].each { |f| require f }

class Churnobyl < Sinatra::Base
  include Authorization

     
  configure :production, :development do
    $logger = Logger.new('log/churnometer.log')
    enable :logging

    $logger = Logger.new('log/churnometer.log')
    
    set :raise_errors, Proc.new { false }
    set :show_exceptions, false

    enable :sessions
    set :session_secret, "something" # I don't understand what this does but it lets my flash work
    use Rack::Session::Pool #  # rack::session::pool handles large cookies for temporary config configuration
    
    set :churn_app_mutex, Monitor.new
  end
  
  # Returns a ChurnometerApp instance.
  def app
    @churn_app ||= self.class.server_lifetime_churnometer_app
  end


  def churn_db_class
    if app().use_database_cache?
      ChurnDBDiskCache
    else
      ChurnDB
    end
  end
  
  def churn_db
    @churn_db ||= churn_db_class().new(app())
  end

  def churn_request_class
    ChurnRequest
  end

  def cr
    @cr ||= churn_request_class().new(request.url, request.query_string, auth, params, app(), churn_db())
    @sql = @cr.sql # This is set for error message
    @cr
  end
  
  def ip
    @ip  ||= ImportPresenter.new(app(), self.class.importer, ChurnDB.new(app())) # don't use the disk cache db for importing!
  end

  def reload_config_on_every_request?
    false
  end

  def allow_http_caching?
    true
  end

  # Returns the single ChurnometerApp instance used throughout the app's execution, across requests.
  def self.server_lifetime_churnometer_app
    # The instance is created lazily, so several threads may attempt to create it at the same time if
    # several requests arrive after the server is first started. The mutex ensures only one app will
    # be created.
    settings.churn_app_mutex.synchronize do
      @server_lifetime_churnometer_app ||= ChurnometerApp.new(settings.environment,  churnometer_app_site_config_io(), churnometer_app_config_io())
    end
  end

  # Return the IO object that config data is loaded from, or 'nil' to use the regular config file locations.
  def self.churnometer_app_config_io
    nil
  end
  
  def self.churnometer_app_site_config_io
    nil
  end

  def self.importer()
    if @importer == nil
      settings.churn_app_mutex.synchronize do 
        @importer = Importer.new(server_lifetime_churnometer_app)
      end
      @importer.run
      end
      @importer
  end
  
  not_found do
    erb :'errors/not_found'
  end
 
  error do
    begin
      @error = env['sinatra.error']
      if app().email_on_error?
        Pony.mail({
                    :to   => app().config.element('email_errors').value['to'].value,
                    :from => app().config.element('email_errors').value['from'].value,
                    :subject => "[Error] #{@error.message}",
                    :body => erb(:'errors/error_email', layout: false)
                  })
      end
      erb :'errors/error'
    rescue StandardError => err
      return response.write "Error in error handler: #{err.message}"
    end
  end 

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
  
  before do
    #cache_control :public, :must_revalidate, :max_age => 60
    @start_time = Time.new
  end  
  
  after '/' do
    log
    @cr.close_db() if !@cr.nil? 
  end
  
  after '/import' do
    log
    @ip.close_db() if !ip.nil?
  end

  def log

    #cache_control :public, :must_revalidate, :max_age => 60
    if app().config['demo']
      Pony.mail({
                :to   => app().config.element('email_errors').value['to'].value,
                :from => app().config.element('email_errors').value['from'].value,
                :subject => "[Demo] #{request.env['HTTP_X_FORWARDED_FOR']}",
                :body => erb(:'demo_email', layout: false)
              })
    end
    
    $logger.info "\t #{ request.env['HTTP_X_FORWARDED_FOR'] } \t #{ request.user_agent } \t #{ request.url } \t #{ ((Time.new - @start_time) * 1000).to_s }"
  end

  get '/' do
    if reload_config_on_every_request?
      app().reload_config(self.class.churnometer_app_config_io(), self.class.churnometer_app_config_io_desc())
    end

    if allow_http_caching?
      cache_control :public, :max_age => 28800
    end

    protected!

    presenter = ChurnPresenter.new(app(), cr)
    
    presenter.warnings += "Your web browser, Internet Explorer, is not HTML5 compliant and will not function correctly" if request.env['HTTP_USER_AGENT'].downcase.index('msie')
    erb :index, :locals => { :model => presenter }
  end

  get '/export_table' do
    protected!
    
    presenter = ChurnPresenter.new(app(), cr)
    table = presenter.tables[params['table']] if !params['table'].nil?
    
    if !table.nil?
      path = table.to_excel
      send_file(path, :disposition => 'attachment', :filename => File.basename(path))
    else
      raise "Export failed. Table not found!"
    end
  end  
  
  get '/export_all' do
    protected!
    
    presenter = ChurnPresenter.new(app(), cr)
    path = presenter.to_excel
    send_file(path, :disposition => 'attachment', :filename => File.basename(path))
  end
  
  get "/import" do
    admin!
    
    @flash = session[:flash]
    session[:flash] = nil
    
    @model = ip()
    
    if params['action'] == "diags"
      response.write @model.diags
      return
    end 
    
    #if params['action'] == "rebuild"
    #  @model.rebuild
    #end 
    
    if params['scripted'] == 'true'
      if @model.importing?
        return response.write @model.import_status
      else 
	      state = ( @model.import_ready? ? "ready to import" : "data not staged" )
        return response.write state + @model.importer_status
      end
    else
      erb :import
    end 
  end
  
  get "/source" do
    @model = ip()
    file = "source_#{Time.now.strftime("%Y-%m-%d_%H.%M.%S")}.zip"
    path = "tmp/source"
    @model.download_source(path)
    send_file("#{path}.zip", :disposition => 'attachment', :filename => file)   
    @model.close_db()
  end
  
  get "/backup" do
    admin!
    
    @flash = session[:flash]
    session[:flash] = nil
    erb :backup
  end
  
  get "/backup_download" do
    admin!
    
    @model = ip()
    file = "backup_#{Time.now.strftime("%Y-%m-%d_%H.%M.%S")}.zip"
    path = "tmp/backup.zip"
    @model.backup(path)
    send_file(path, :disposition => 'attachment', :filename => file)
    @model.close_db()
  end
  
  get "/restart" do
    admin!
    
    @flash = session[:flash]
    session[:flash] = nil
    erb :restart
  end
  
  post "/restart" do
    admin!
    
    @model = ip()
    @model.restart
  end
  
  post "/import" do
    admin!
    
    session[:flash] = nil
    @model = ip()
    
    if params['action'] == "reset"
      @model.reset
      session[:flash] = "Successfully emptied staging tables"
      redirect '/import'
    end 
    
    if params['action'] == "import"
      if @model.import_ready? 
        @model.go(Time.parse(params['import_date']))
        session[:flash] = "Successfully commenced import of staged data"
      
        if params['scripted'] == 'true'
          return response.write session[:flash]
        else
          redirect '/import'
        end
      else
        session[:flash] = "Data not staged for import"

        if params['scripted'] == 'true'
          return response.write session[:flash]
        else
          redirect '/import'
        end
      end
    end

    
    if params['action'] == "empty_cache"
      begin
        @model.empty_cache()
      rescue StandardError => err
        raise err if ! (err.message == 'rm: tmp/*.Marshal: No such file or directory')
      end
            
      session[:flash] = "Successfully emptied cache"
      if params['scripted'] == 'true'
        return response.write session[:flash]
      else
        redirect '/import'
      end
    end  
    
    #if params['action'] == "rebuild"
    #  @model.rebuild
    #  redirect '/import'
    #end 
    
    if params['action'] == "diags"
      response.write @model.diags
      return
    end 
    
    if params['myfile'].nil?
      session[:flash]="No file uploaded"
      redirect '/import'
    end
    
    file = params['myfile'][:tempfile] 
    filename = params['myfile'][:filename]
    
    begin
      full_filename = 'uploads/' + filename + '.' + Time.now.strftime("%Y-%m-%d_%H.%M.%S")
      
      File.open(full_filename, "w") do |f|
        f.write(file.read)
      end
      
      if filename.start_with?("members.txt") then
        @model.member_import(full_filename)
      end
      
      if filename.start_with?("displaytext.txt") then
        @model.displaytext_import(full_filename)
      end
      
      if filename.start_with?("transactions.txt") then
        @model.transaction_import(full_filename)
      end
      
    rescue StandardError => err
      session[:flash] = "File upload failed: " + err.message
    end
    
    if session[:flash].nil?
      session[:flash] = "#{filename} was successfully uploaded"
    end
    
    if params['scripted']=='true'
      response.write session[:flash] # so CURL doesn't have to redirect to get
    else
      redirect '/import'
    end
  end

  get '/config' do 
    admin!
    
    @flash = session[:flash]
    session[:flash] = nil
    
    @config = ""
    File.open("config/config.yaml", 'r') do |f|
      while line=f.gets
        @config+=line
      end
    end
    
    erb :config
  end
  
  post '/config' do
    admin!
    
    @flash = nil
    @config = params['config']
    begin
      
      if ! (@config.nil? || @config.empty?) 
        
        testConfig = ChurnometerApp.new(settings.environment, nil, StringIO.new(@config))
        testConfig.validate
        dbm = DatabaseManager.new(testConfig)
        @yaml_spec = dbm.migration_yaml_spec
        if @yaml_spec.nil?
          File.open("config/config.yaml", 'w') do |f|
            f.puts @config
          end
        else
          session[:flash] = "Need to restructure data before saving config/config.yaml"
          session[:new_config] = params['config']
          redirect :migrate
        end
      else
        raise "empty config!"
      end
    rescue StandardError => err
      @flash = "Failed to save config/config.yaml: " + err.message
    rescue Psych::SyntaxError => err
      @flash = "Failed to save config/config.yaml: " + err.message
    end
    
    return erb :config if !@flash.nil?
    
    session[:flash] = "Successfully saved config/config.yaml "
    redirect '/restart?redirect=/config'
  end

  get '/migrate' do
    admin!
    
    @flash = session[:flash]
    @config = session[:new_config]
    if @config.nil?
      session[:flash] = "Can't migrate with out new config.  Make sure cookies are enabled."
      redirect :config 
    end
    
    # get new config and dimensions
    new_config = ChurnometerApp.new(settings.environment, nil, StringIO.new(@config))
    dbm = DatabaseManager.new(new_config)
    
    # get the proposed migration, and return it to the user to allow intervention
    @yaml_spec = dbm.migration_yaml_spec
    erb :migrate
  end
  
  post '/migrate' do
    admin!
    
    @flash = nil
    session[:flash] = nil
    @yaml_spec = params['yaml_spec']
    @config = session[:new_config]
    if @config.nil?
      session[:flash] = "Can't migrate with out new config.  Make sure cookies are enabled."
      redirect :config 
    end
    
    # attempt migration using user supplied spec
    begin 
      new_config = ChurnometerApp.new(settings.environment, nil, StringIO.new(@config))
      dbm = DatabaseManager.new(new_config)
      migration_spec = dbm.parse_migration(@yaml_spec)
      
      migration_sql = dbm.migrate_sql(migration_spec)
      raise "User specified script only" if params['script_only'] == 'true'
      
      dbm.migrate(migration_sql) # this can take some serious time
    rescue StandardError => err
      @flash = "Failed to migrate: " + err.message + " <br/> see below for diagnostic sql"
      @diag_sql = migration_sql
    rescue Psych::SyntaxError => err
      @flash = "Failed to migrate: " + err.message
    end
    
    return erb :migrate if !@flash.nil? # problem migrating
    session[:config] = nil
    
    # If we made it this far, save the new config
    begin
      File.open("config/config.yaml", 'w') do |f|
        f.puts @config
      end
    rescue StandardError => err
      @flash = "This is bad.  Successfully migrated database but to save config/config.yaml: " + err.message
    end
    
    return erb :config if !@flash.nil? # problem saving config, should be able to render from @config
    session[:flash] = "Successfully restructed database and saved config/config.yaml"
    redirect '/restart?redirect=/config'
  end

  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  ServiceRequestHandlerAutocomplete.new(self)

  run! if app_file == $0
  
end
