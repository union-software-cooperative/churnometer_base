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
  logger = Logger.new('log/churnometer.log')
     
  configure :production, :development  do
    set :session_secret, "something" # I don't understand what this does but it lets my flash work
    enable :sessions
  end 
  
  configure :production, :development do
    enable :logging

    set :churn_app, ChurnometerApp.new 
  end
  
  $importer = Importer.new
  $importer.run
  
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
    if Config['demo']
      Pony.mail({
                :to   => Config['email_errors']['to'],
                :from => Config['email_errors']['from'],
                :subject => "[Demo] #{request.env['HTTP_X_FORWARDED_FOR']}",
                :body => erb(:'demo_email', layout: false)
              })
    end
    
    logger.info "\t #{ request.env['HTTP_X_FORWARDED_FOR'] } \t #{ request.user_agent } \t #{ request.url } \t #{ ((Time.new - @start_time) * 1000).to_s }"
  end

  def app
    @churn_app ||= settings.churn_app
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

  get '/self' do
    sleep 10
    h self.to_s
  end

  get '/' do
    cache_control :public, :max_age => 28800
    protected!
    
    presenter = ChurnPresenter.new(app(), cr)

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
