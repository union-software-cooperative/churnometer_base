require 'rubygems'
require 'bundler/setup'

require './lib/ruby_changes'
require './lib/constants'
require './lib/helpers'
require './lib/db'
require './lib/data_sql'
require './lib/authorization'

require 'sinatra/base'

require 'pg'
require 'sass'
require 'erb'
require 'uri'
require 'spreadsheet'
require 'money'
require "addressable/uri"

require 'ir_b'

class Churnobyl < Sinatra::Base
  include DataSql
  include Authorization

  before do
    #cache_control :public, :must_revalidate, :max_age => 60
  end

  get '/dev' do
    erb :index  
  end

  get '/get_data' do
    @data = db.ex params[:sql]
    erb :summary
  end

  get '/scss/:name.css' do |name|
    scss name.to_sym, :style => :expanded
  end

  get '/' do
    cache_control :public, :max_age => 43200
    protected!
  
    fix_date_params
   
    @sql = query['column'].empty? ? summary_sql : member_sql
  
    @data = db.ex @sql
  
    erb :summary
  end

  get '/export_summary' do
    fix_date_params
  
    data_to_excel db.ex(summary_sql)
  end

  get '/export_member_details' do
    fix_date_params
  
    data_to_excel db.ex(member_sql)
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
  
  run! if app_file == $0
end


