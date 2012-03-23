require 'rubygems'
require 'sinatra/base'

require 'bundler/setup'
require 'pg'
require 'sass'
require 'erb'
require 'uri'
require 'spreadsheet'
require 'money'
require "addressable/uri"
require 'pony'

require 'ir_b'

Config = YAML.load(File.read("./config/config.yaml"))
Dir["./lib/*.rb"].each { |f| require f }

class Churnobyl < Sinatra::Base
  include Authorization
  include Support

  before do
    #cache_control :public, :must_revalidate, :max_age => 60
  end

  get '/' do
     
    @warning = fix_date_params
    
    # if !data_sql.query['site_constrain'].nil?
    #       sql = data_sql.sites_at_date(leader?)
    #       sites = db.ex(sql)
    #       companyids = sites.collect{ |r| r['companyid']}.join(',')
    #       if companyids.empty? 
    #           companyids = 'none' 
    #       end
    #       
    #       dest = "/?startDate=#{h data_sql.query['startDate']}&endDate=#{h data_sql.query['endDate']}&group_by=#{h data_sql.query['group_by']}&lock[companyid]=#{h companyids}" 
    # 
    #       redirect URI.encode(dest)
    #       @warning += h sql + "<br />"
    #       @warning += h companyids + "<br />"
    #     end
    
    #cache_control :public, :max_age => 1
    protected!
    
    @sql = data_sql.query['column'].empty? ? data_sql.summary_sql(leader?) : data_sql.member_sql(leader?)
    @data = DataPresenter.new db.ex(@sql)  
    
    if !@data.has_data?
      @warning += 'WARNING:  No data found'
    end
    
    if data_sql.transfers?(@data)
      @warning += 'WARNING:  There are transfers during this period that may influence the results.  See the transfer tab below. <br />'
    end
    
    erb :summary
  end

  get '/get_data' do
    @sql = params[:sql]
    @data = DataPresenter.new db.ex(@sql)
    erb :summary
  end

  get '/dev' do
    erb :dev  
  end

  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  get '/export_summary' do
    fix_date_params
  
    data_to_excel db.ex(data_sql.summary_sql(leader?))
  end

  get '/export_member_details' do
    fix_date_params
  
    data_to_excel db.ex(data_sql.member_sql(leader?))
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  
    include Helpers
  end

  def db
    @db ||= Db.new
  end
  
  def data_sql
    @data_sql ||= DataSql.new params
  end
  
  run! if app_file == $0
end



