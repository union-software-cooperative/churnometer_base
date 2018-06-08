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

require 'pry'
require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/json'
require 'bundler/setup'
require 'pg'
require 'sass'
require 'erb'
require 'uri'
require 'money'
require "addressable/uri"
require 'pony'
require 'monitor' # used for managing potentially recursive mutexes on Class singletons
require "sinatra/streaming"

Dir["./lib/*.rb"].each { |f| require f }
Dir["./lib/services/*.rb"].each { |f| require f }
Dir["./lib/query/*.rb"].each { |f| require f }
Dir["./lib/import/*.rb"].each { |f| require f }
Dir["./lib/churn_presenters/*.rb"].each { |f| require f }

class ApplicationController < Sinatra::Base
  include ChurnLogger

  configure :development do
    register Sinatra::Reloader
  end

  configure :production, :development do

    # enable :logging
    # file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    # file.sync = true
    # use Rack::CommonLogger, file

    enable :sessions
    set :session_secret, "something" # I don't understand what this does but it lets my flash work
    use Rack::Session::Pool #  # rack::session::pool handles large cookies for temporary config configuration

    set :churn_app_mutex, Monitor.new
  end

  # Returns a ChurnometerApp instance.
  def app
    @churn_app ||= self.class.server_lifetime_churnometer_app
  end

  # Halt processing and redirect to the URI provided.
  def redirect(uri, *args)
    log.info "#{request.env['HTTP_X_FORWARDED_FOR']} 302 Found, redirecting to #{uri}"
    super
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
    @ip = ImportPresenter.new(app(), self.class.importer, ChurnDB.new(app())) # don't use the disk cache db for importing!
  end

  def reload_config_on_every_request?
    false
  end

  def allow_http_caching?
    true
  end

  def testing?
    false
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
    #@importer ||= Importer.new(server_lifetime_churnometer_app)
    @importer = Importer.new(server_lifetime_churnometer_app)
  end

  not_found do
    erb :'errors/not_found'
  end

  error do
    begin
      @error = env['sinatra.error']
      # #if app().email_on_error?
      #   Pony.mail({
      #               :to   => app().email_on_error_from,
      #               :from => app().email_on_error_to,
      #               :subject => "[Error] #{@error.message}",
      #               :body => erb(:'errors/error_email', layout: false)
      #             })
      # end
      erb :'errors/error'
    rescue StandardError => err
      return response.write "Error in error handler: #{err.message}"
    end
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end

  helpers Sinatra::Streaming

  before do
    #cache_control :public, :must_revalidate, :max_age => 60
    @start_time = Time.new
    log.info "#{request.env['HTTP_X_FORWARDED_FOR']} Started  #{request.env['REQUEST_METHOD']} #{request.env['REQUEST_URI']} for #{request.user_agent} #{request.env['REMOTE_ADDR']}"
  end
end

class OAuthController < ApplicationController
  include Oauth2Authorization

  after do
    log.info "#{request.env['HTTP_X_FORWARDED_FOR']} Finished #{request.env['REQUEST_METHOD']} #{request.env['REQUEST_URI']} for user #{@auth.name}"
  end

  after '/' do
    @cr.close_db() if !@cr.nil?
    @cr = nil if testing?
  end

  # ?client_id=8052fa6780844bc36b816f1d077fc54c15b678c9322ed747b1f4d38a336754db&redirect_uri=http%3A%2F%2Fwww%3A9292%2Foauth2-callback&response_type=code&scope=profile
  # http://www:9292/oauth2-callback?code=04cc6aaeae6d3cae7577c7394b64964b2ce3b8f7b714a0f4c5f95fc88b91db48
  get '/oauth2-callback' do
    return_to = params['return_to'] ? params['return_to'] : '/'

    redirect_url = URI.join(oauth2_redirect_uri, "?return_to=#{CGI::escape(return_to)}").to_s
    puts "CALLBACK: " + redirect_url
    new_token = oauth2_client.auth_code.get_token(params[:code], :redirect_uri => redirect_url)
    session[:access_token]  = new_token.token
    session[:refresh_token] = new_token.refresh_token
    response['Cache-Control'] = "no-cache"

    redirect CGI::unescape(return_to)
  end

  get '/logout' do
    session.clear
    redirect ENV['OAUTH2_PROVIDER'] + "/logout"
  end

  get '/account' do
    session.clear
    redirect ENV['OAUTH2_PROVIDER']
  end

  get '/' do
    if reload_config_on_every_request?
      app().reload_config(self.class.churnometer_app_site_config_io(), self.class.churnometer_app_config_io())
    end

    if allow_http_caching?
      # cache_control :public, :max_age => 28800
      cache_control :no_cache
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
      case params['format']
      when 'csv' then send_file(table.to_csv, :disposition => 'attachment', :filename => File.basename(path))
      when 'json' then json(table.raw_data)
      when 'xls', nil then send_file(table.to_excel, :disposition => 'attachment', :filename => File.basename(table.to_excel))
      else raise("Export failed. Invalid format!")
      end
    else
      raise "Export failed. Table not found!"
    end
  end

  get '/export_target' do
    protected!
    presenter = ChurnPresenter.new(app(), cr)
    target = presenter.target

    result = { growth: target.growth, periods: target.periods, period_desc: target.period_desc, cards_in: target.get_cards_in, cards_in_target: target.get_cards_in_target, cards_in_growth_target: target.get_cards_in_growth_target, real_loss: target.get_real_losses, paying_net: target.get_paying_net }
    json(result)
  end

  get '/export_all' do
    protected!

    presenter = ChurnPresenter.new(app(), cr)
    path = presenter.to_excel
    send_file(path, :disposition => 'attachment', :filename => File.basename(path))
  end

  get "/backup_download" do
    admin!

    @model = ip()
    file = "backup_#{Time.now.strftime("%Y-%m-%d_%H.%M.%S")}.zip"
    path = "backup/backup.zip"
    @model.backup(path)
    send_file(path, :disposition => 'attachment', :filename => file)
    @model.close_db()
  end

  get "/regenerate_cache", provides: 'text/event-stream'  do
    admin!

    #TODO make this stream
    stream do |out|
      out.write "Cache regeneration started\n"
      db = ChurnDBDiskCache.new(app())
      Thread.new do
        db.regenerate_cache(files_only: true, since: '2017-01-01')
      end

      begin
        out.write ChurnDBDiskCache.regeneration_status + "\n"
        out.flush
        sleep 1
      end while ChurnDBDiskCache.regeneration_status.start_with?('in progress')
      out.write "Cache regeneration started\n"
      out.flush
    end
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
    @memberfacthelper_migration_required = dbm.memberfacthelper_migration_required?
    erb :migrate
  end

  get '/backdate' do
    admin!

    @dimensions = (params['dimensions']||"").split(',')
    @back_to = Date.parse(params['back_to']) rescue nil

    if @dimensions == []
      session[:flash] = "you must provide a comma separated set of 'dimensions'"
      redirect :config
    end

    if @back_to.nil?
      session[:flash] = "you must provide a 'back_to' date to backdate to"
      redirect :config
    end

    # get new config and dimensions
    dbm = DatabaseManager.new(app())
    dbm.backdate_sql(@dimensions, @back_to)
  end

  post '/migrate' do
    admin!

    @flash = nil
    session[:flash] = nil
    @yaml_spec = params['yaml_spec']
    @config = session[:new_config]

    if @config.nil?
      session[:flash] = "Can't migrate without new config.  Make sure cookies are enabled."
      redirect :config
    end

    need_full_migration = @yaml_spec.nil? == false

    # attempt migration using user supplied spec
    begin
      new_config = ChurnometerApp.new(settings.environment, nil, StringIO.new(@config))

      dbm = DatabaseManager.new(new_config)

      migration_sql =
        if need_full_migration
          migration_spec = dbm.parse_migration(@yaml_spec)

          #dbm.migrate_nuw_sql(migration_spec) # use this line in place of the one below when migrating from NUW
          dbm.migrate_sql(migration_spec)
        else
          dbm.rebuild_memberfacthelper_sql_ary
        end

      #migration_sql = dbm.migrate_asu_sql(dbm.parse_migration(dbm.migration_spec_all.to_yaml))

      if params['script_only'] == 'true'
        "<html><head><pre>User specified script only\n\n#{migration_sql.join($/)}</pre></head></html>"
      else
        stream do |io|
          thread = nil
          error = nil

          io << "<html><head><title>Churnometer migration in progress.</title></head><body>"

          thread = Thread.new do
            io << "<div><span>Please wait</span></span>"
            begin
              io << " . "
              sleep 1
            end while !Thread.current[:finished]
            io << "</span>"
          end.run

          migrate_result = true

          begin
            migrate_result = dbm.migrate(migration_sql, need_full_migration == true) # this can take some serious time
          rescue StandardError => err
            error = err.message + ". Diagnostic sql: #{migration_sql.join($/)}"
          rescue Psych::SyntaxError => err
            error = err.message
          ensure
            thread[:finished] = true if !thread.nil?
          end

          io << "</div>"

          if migrate_result != true
            io << "<div>A non-fatal error occurred during the migration:</div>"
            io << "<pre>#{h(migrate_result).gsub('\n', '</br>')}</pre>"
          end

          if !error.nil?
            io << "<div>The migration failed with the following error:</div>"
            io << "<pre>#{h(error).gsub('\n', '</br>')}</pre>"
            io << "<div><a href='/migrate'>Back to migration page.</a></div>"
          else
            io << "<div>Migration successful.</div>\n"

            # If we made it this far, save the new config
            begin
              File.open(app().active_master_config_filename, 'w') do |f|
                f.write @config
              end
            rescue StandardError => err
              error = "Successfully migrated database but failed to save #{app().active_master_config_filename}: " + err.message
            end

            if !error.nil?
              io << "<div>An error occurred while writing the config file: <pre>#{h(error).gsub('\n', '</br>')}</pre></div>"
              io << "<div>Please record (copy and paste) the following config data before leaving this page:</div>"
              io << "<pre>#{h @config}</pre>"
              io << "<a href='/migrate'>Back to config page.</a>"
            else
              io << "<div>Successfully restructured database and saved config/config.yaml</div>"
              io << "<div>The server must be restarted now.</div>"
              io << "<div><a href='/restart?redirect=/config'>Click here to restart server.</a></div>"
            end
          end

          io << "</body></html>"
        end
      end
    end
  end
end

class BasicAuthController < ApplicationController
  include BasicAuthorization

  after do
    log.info "#{request.env['HTTP_X_FORWARDED_FOR']} Finished #{request.env['REQUEST_METHOD']} #{request.env['REQUEST_URI']} for role #{@auth.role.id}"
  end

  after '/import' do
    # log
    @ip.close_db() unless @ip.nil?
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

  get "/backup" do
    admin!

    @flash = session[:flash]
    session[:flash] = nil
    erb :backup
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
        f.write(file.read.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '?'))
      end

      if app().database_import_encoding && app().database_import_encoding != 'utf-8'
        iconv_filename = "#{full_filename}-utf8"
        iconv_result = `iconv -f '#{app().database_import_encoding}' -t 'utf-8' -o "#{iconv_filename}" "#{full_filename}"`
        $stderr.puts iconv_result
        raise "Failed to convert file to utf-8: #{iconv_result}" if $? != 0
        File.delete(full_filename)
        full_filename += "-utf8"
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

    # write flash to stderr in case something goes wrong with presenting the flash.
    $stderr.puts session[:flash]

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

    filename = app().active_master_config_filename

    @config = ""
    File.open(filename, 'r') do |f|
      while line=f.gets
        @config+=line
      end
    end

    erb :config, :locals => {:filename => filename}
  end

  post '/config' do
    admin!

    @flash = nil
    @config = params['config']

    filename = app().active_master_config_filename

    begin
      if ! (@config.nil? || @config.empty?)

        testConfig = ChurnometerApp.new(settings.environment, nil, StringIO.new(@config))
        testConfig.validate
        dbm = DatabaseManager.new(testConfig)
        @yaml_spec = dbm.migration_yaml_spec
        if @yaml_spec.nil? && dbm.memberfacthelper_migration_required? == false
          File.open(filename, 'w') do |f|
            f.write @config
          end
        else
          flash_text = "Need to restructure data before saving #{filename}"
          flash_text += " (memberfacthelper requires update)" if dbm.memberfacthelper_migration_required?

          session[:flash] = flash_text
          session[:new_config] = params['config']
          redirect :migrate
        end
      else
        raise "empty config!"
      end
    rescue StandardError => err
      @flash = "Failed to save #{filename}: " + err.message
    rescue Psych::SyntaxError => err
      @flash = "Failed to save #{filename}: " + err.message
    end

    return erb :config, :locals => {:filename => filename} if !@flash.nil?

    session[:flash] = "Successfully saved #{filename}"
    redirect '/restart?redirect=/config'
  end
end

class PublicController < ApplicationController
  after do
    log.info "#{request.env['HTTP_X_FORWARDED_FOR']} Finished #{request.env['REQUEST_METHOD']} #{request.env['REQUEST_URI']} anonymously"
  end

  get "/source" do
    @model = ip()
    file = "source_#{Time.now.strftime("%Y-%m-%d_%H.%M.%S")}.zip"
    path = "tmp/source"
    @model.download_source(path)
    send_file("#{path}.zip", :disposition => 'attachment', :filename => file)
    @model.close_db()
  end

  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  ServiceRequestHandlerAutocomplete.new(self)
end
#
# class Churnobyl < Sinatra::Base
#   run! if app_file == $0
# end
