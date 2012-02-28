require 'rubygems'
require 'bundler/setup'

require 'sinatra/base'

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

  before do
    #cache_control :public, :must_revalidate, :max_age => 60
  end

  get '/' do
    cache_control :public, :max_age => 43200
    protected!
  
    fix_date_params
   
    @sql = data_sql.query['column'].empty? ? data_sql.summary_sql(leader?) : data_sql.member_sql
    @data = db.ex @sql
  
    erb :summary
  end

  get '/get_data' do
    @sql = params[:sql]
    @data = db.ex @sql
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
  
    data_to_excel db.ex(data_sql.member_sql)
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  
    include Helpers
  end

  def data_to_excel(data)
    @data = data
    book = Spreadsheet::Excel::Workbook.new
    sheet = book.create_worksheet
  
    if has_data?
    
      #Get column list
      if params['table'].nil?
        cols = @data[0]
      elsif summary_tables.include?(params['table'])
          cols = summary_tables[params['table']]
      else
        cols = ['memberid'] | member_tables[params['table']]  
      end
    
      # Add header
      merge_cols(@data[0], cols).each_with_index do |hash, x|
        sheet[0, x] = col_names[hash.first] || hash.first
      end
  
      # Add data
      @data.each_with_index do |row, y|
        merge_cols(row, cols).each_with_index do |hash,x|
        
          if filter_columns.include?(hash.first) 
            sheet[y + 1, x] = hash.last.to_i
          else
              sheet[y + 1, x] = hash.last
          end  
      
        end
      end
    end
  
    path = "tmp/data.xls"
    book.write path
  
    send_file(path, :disposition => 'attachment', :filename => File.basename(path))
  end

  def db
    @db ||= Db.new
  end
  
  def data_sql
    @data_sql ||= DataSql.new params
  end
  
  run! if app_file == $0
end



