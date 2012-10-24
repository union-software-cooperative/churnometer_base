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

Dir["./lib/*.rb"].each { |f| require f }
Dir["./lib/services/*.rb"].each { |f| require f }
Dir["./lib/query/*.rb"].each { |f| require f }
Dir["./lib/import/*.rb"].each { |f| require f }
Dir["./lib/churn_presenters/*.rb"].each { |f| require f }

class Churnobyl < Sinatra::Base
  include Authorization

  # Returns a ChurnometerApp instance.
  def app
    @churn_app ||= self.class.server_lifetime_churnometer_app
  end

  def churn_db
    @churn_db ||= churn_db_class().new(app())
  end

  def cr
    @cr ||= churn_request_class().new(request.url, request.query_string, auth, params, app(), churn_db())
    @sql = @cr.sql # This is set for error message
    @cr
  end

  def churn_request_class
    ChurnRequest
  end

  def churn_db_class
    if app().use_database_cache?
      ChurnDBDiskCache
    else
      ChurnDB
    end
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
      @server_lifetime_churnometer_app ||= ChurnometerApp.new(settings.environment, churnometer_app_config_io(), churnometer_app_config_io_desc())
    end
  end

  # Return the IO object that config data is loaded from, or 'nil' to use the regular config file
  # locations.
  def self.churnometer_app_config_io
    nil
  end

  def self.churnometer_app_config_io_desc
    nil
  end

  set :raise_errors, false
  set :show_exceptions, false

  logger = Logger.new('log/churnometer.log')
     
  configure :production, :development  do
  end 
  
  configure :production, :development do
    set :session_secret, "something" # I don't understand what this does but it lets my flash work
    enable :sessions
    
    enable :logging
    set :churn_app_mutex, Mutex.new
  end
  
  not_found do
    erb :'errors/not_found'
  end
  
  $importer = Importer.new(server_lifetime_churnometer_app)
  $importer.run
  
  error do
    @error = env['sinatra.error']

    if app().nil? || app().email_on_error?
      Pony.mail({
                  :to   => app().config['email_errors'].value['to'].value,
                  :from => app().config['email_errors'].value['from'].value,
                  :subject => "[Error] #{@error.message}",
                  :body => erb(:'errors/error_email', layout: false)
                })
    end
    
    erb :'errors/error'
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
  end
  
  after '/upload/' do
    log
  end

  def log

    #cache_control :public, :must_revalidate, :max_age => 60
    if app().config['demo']
      Pony.mail({
                :to   => Config['email_errors']['to'],
                :from => Config['email_errors']['from'],
                :subject => "[Demo] #{request.env['HTTP_X_FORWARDED_FOR']}",
                :body => erb(:'demo_email', layout: false)
              })
    end
    
    logger.info "\t #{ request.env['HTTP_X_FORWARDED_FOR'] } \t #{ request.user_agent } \t #{ request.url } \t #{ ((Time.new - @start_time) * 1000).to_s }"
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
    @flash = session[:flash]
    session[:flash] = nil
    
    @model = ImportPresenter.new(app())
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
  
  post "/import" do
    session[:flash] = nil
    @model = ImportPresenter.new(app())
    
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
    
    if params['action'] == "rebuild"
      @model.rebuild
      redirect '/import'
    end 
    
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
  
  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  ServiceRequestHandlerAutocomplete.new(self)

  run! if app_file == $0
  
end
