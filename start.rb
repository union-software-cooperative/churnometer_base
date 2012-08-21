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

Config = YAML.load(File.read("./config/config.yaml"))
Dir["./lib/*.rb"].each { |f| require f }
Dir["./lib/services/*.rb"].each { |f| require f }
Dir["./lib/churn_presenters/*.rb"].each { |f| require f }

class Churnobyl < Sinatra::Base
  include Authorization
  
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
  
  before do
    #cache_control :public, :must_revalidate, :max_age => 60
  end  
  
  def cr
    @cr ||= ChurnRequest.new request.url, auth, params, ChurnDBDiskCache.new
    @sql = @cr.sql # This is set for error message
    @cr
  end
  
  get '/' do
    cache_control :public, :max_age => 28800
    protected!
    
    presenter = ChurnPresenter.new cr
    
    erb :index, :locals => {:model => presenter }
  end

  get '/export_table' do
    protected!
    
    query = ChurnRequest.new request.url, auth, params, ChurnDBDiskCache.new
    presenter = ChurnPresenter.new query
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
    
    query = ChurnRequest.new request.url, auth, params, ChurnDBDiskCache.new
    presenter = ChurnPresenter.new query
    path = presenter.to_excel
    send_file(path, :disposition => 'attachment', :filename => File.basename(path))
  end
  
  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  ServiceRequestHandlerAutocomplete.new(self)

  run! if app_file == $0
end



