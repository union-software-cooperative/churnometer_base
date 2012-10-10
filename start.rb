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
Dir["./lib/churn_presenters/*.rb"].each { |f| require f }

class Churnobyl < Sinatra::Base
  include Authorization
  logger = Logger.new('log/churnometer.log')
      
  configure :production, :development do
    enable :logging

    set :churn_app, ChurnometerApp.new 
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
  
  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  ServiceRequestHandlerAutocomplete.new(self)

  run! if app_file == $0
end



