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

  def db
    @db ||= Db.new
  end
  
  def churn_data
    @churn_data ||= ChurnData.new db, params
  end
  
  before do
    #cache_control :public, :must_revalidate, :max_age => 60
  end

  def query(churn_data, params)
    @warning = validate_params(churn_data, params)
    
    start_date = Date.parse('2011-8-14').strftime(DateFormatDisplay)
    end_date = Time.now.strftime(DateFormatDisplay)

    {
      'group_by' => 'branchid',
      'startDate' => start_date,
      'endDate' => end_date,
      'column' => '',
      'interval' => 'none',
      Filter => {
        'status' => [1, 14, 11]
      }
    }.rmerge(params)
  end

  get '/' do
     
    @warning = validate_params
    
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
    
    cache_control :public, :max_age => 28800
    protected!
    
    @sql = data_sql.query['column'].empty? ? data_sql.summary_sql(leader?) : data_sql.member_sql(leader?)
    @data = ChurnPresenter.new db.ex(@sql)  
    
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
    @data = ChurnPresenter.new db.ex(@sql)
    erb :summary
  end

  get '/dev' do
    erb :dev  
  end

  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  get '/export_summary' do
    validate_params
  
    @data = ChurnPresenter.new db.ex(data_sql.summary_sql(leader?)), params, leader?, staff?
    @data.to_excel
  end

  get '/export_member_details' do
    @query = query(churn_data, params)
    @data = churn_data.detail(@query, leader?)
    @data = ChurnPresenter.new @data, @query, leader?, staff?
    
    path = @data.to_excel
    send_file(path, :disposition => 'attachment', :filename => File.basename(path))
  end


  run! if app_file == $0
end



