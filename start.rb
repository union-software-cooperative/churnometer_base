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
  
  def db
    @db ||= ChurnData.new
  end
  
  def query
    if @query.nil? 
      @warning = validate_params

      start_date = Date.parse('2011-8-14').strftime(DateFormatDisplay)
      end_date = Time.now.strftime(DateFormatDisplay)

      @query = {
        'group_by' => 'branchid',
        'startDate' => start_date,
        'endDate' => end_date,
        'column' => '',
        'interval' => 'none',
        Filter => {
          'status' => [1, 14, 11] # todo - get rid of this because excepts are required for it when displaying filters
        }
      }.rmerge(params)
    end
    
    @query
  end

  get '/' do
    cache_control :public, :max_age => 28800
    protected!
    
    @data = query['column'].empty? ? db.summary(query, auth.leader?) : db.detail(query, auth.leader?)
    @presenter = ChurnPresenter.new @data, query, auth
    
    if !@presenter.has_data?
      @warning += 'WARNING:  No data found'
    end
    
    if @presenter.transfers.exists?
      @warning += 'WARNING:  There are transfers during this period that may influence the results.  See the transfer tab below. <br />'
    end
    
    erb :index, :locals => {:model => @presenter, :params => query, :warning => @warning}
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
    @data = db.detail(query, leader?)
    @data = ChurnPresenter.new @data, query, leader?, staff?
    
    path = @data.to_excel
    send_file(path, :disposition => 'attachment', :filename => File.basename(path))
  end


  def validate_params
    # @uri when constructing html links - it is better than request.url because we can remove parameters that don't pass validation
    # do a bunch of replacements to simplify swapping url parameters with search and replace 
    @uri= request.url.gsub('+', ' ').gsub('%20', ' ').gsub(' =','=').gsub('= ', '=')
  
    warning = ''
  
      # override date filters with interval filters
    startDate = nil;
    endDate = nil;
    if !params['startDate'].nil?
      startDate = Date.parse(params['startDate'])
    end
    if !params['endDate'].nil?
      endDate = Date.parse(params['endDate'])
    end
    if !params['intervalStart'].nil?
      startDate = Date.parse(params['intervalStart'] )
    end
    if !params['intervalEnd'].nil?
      endDate = Date.parse(params['intervalEnd'])
    end

    if startDate.nil?
      startDate = EarliestStartDate
    end

    if endDate.nil?
      endDate = Date.today
    end
  
    # make sure startDate isn't before data began
    startdb = Date.parse((db.getdimstart(params['group_by']))[0]['getdimstart'])+1
    if startdb > startDate
      startDate = startdb
      warning += 'WARNING: Adjusted start date to when we first started tracking ' + (params['group_by'] || 'branchid') + ' (you had selected ' + params['startDate'] + ')<br/>'
    end

    # make sure endDate isn't in the future or before startDate
    if Date.today < endDate
      endDate = Date.today
      warning += 'WARNING: Adjusted end date to today (you had selected ' + params['endDate'] + ') <br/>'
    end

    if Date.today < startDate
      startDate = Date.today
      warning += 'WARNING: Adjusted start date to today (you had selected ' + params['startDate'] + ')<br/>'
    end

    if startDate > endDate
      endDate = startDate
      warning += "WARNING: Adjusted end date to #{endDate.strftime(DateFormatDisplay)} (you had selected #{ params['endDate'] })<br/>"
    end

    if (!params['startDate'].nil? || !params['intervalStart'].nil?)
      @uri = @uri.sub("startDate=#{params['startDate']}", "startDate=#{startDate.strftime(DateFormatDisplay)}")
      params['startDate'] = startDate.strftime(DateFormatDisplay)
    end
    if (!params['endDate'].nil? || !params['intervalEnd'].nil?)
      @uri = @uri.sub("endDate=#{params['endDate']}", "endDate=#{endDate.strftime(DateFormatDisplay)}")
      params['endDate'] = endDate.strftime(DateFormatDisplay)
    end
    # I don't know what these global values are for
    @start = startDate
    @end = endDate
  
    if (params['group_by']!='companyid' &&  !(params['site_constrain'] == '' || params['site_constrain'].nil?))
      @uri = @uri.gsub("site_constrain=#{params['site_constrain']}", '')
      @uri = @uri.gsub('&&', '&')
      params['site_constrain'] = ''
      warning +="WARNING:  Disabled site constraint because it only makes sense when grouping by Work Site <br/>"
    end
  
    #warning +=h @uri
  
    warning
  end
  

  run! if app_file == $0
end



