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

class Churnobyl < Sinatra::Base
  include Authorization
  include Support
  
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  
    include Helpers
  end

  before do
    #cache_control :public, :must_revalidate, :max_age => 60
  end  
  
  get '/' do
    cache_control :public, :max_age => 28800
    protected!
    
    query = ChurnRequest.new request.url, auth, params
    presenter = ChurnPresenter.new query
    
    erb :index, :locals => {:model => presenter }
  end

  get '/export' do
    protected!
    
    query = ChurnRequest.new request.url, auth, params
    presenter = ChurnPresenter.new query
    table = presenter.tables[params['table']]
    
    if !table.nil?
      path = table.to_excel
      send_file(path, :disposition => 'attachment', :filename => File.basename(path))
    end
  end  
  
  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  run! if app_file == $0
end



