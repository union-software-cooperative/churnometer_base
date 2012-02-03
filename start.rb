require 'rubygems'
require 'bundler/setup'

require './lib/helpers'
require './lib/db'
require './lib/data_sql'
require './lib/ruby_changes'

require 'sinatra'

require 'pg'
require 'sass'
require 'erb'
require 'uri'
require 'spreadsheet'

# require 'ir_b'


# Short names to help shorten URL
Filter = "f"
FilterNames = "fn"

include Churnobyl::DataSql

get '/' do
  erb :index  
end

get '/get_data' do
  @defaults = defaults
  @data = db.ex params[:sql]
  erb :summary
end

get '/scss/:name.css' do |name|
  scss name.to_sym, :style => :expanded
end

get '/summary' do
  @defaults = defaults
  @sql = summary_sql
  @data = db.ex @sql
  # @data = []
  erb :summary
end

get '/export' do
  @data = db.ex member_sql
  book = Spreadsheet::Excel::Workbook.new
  sheet = book.create_worksheet
  
  if has_data?
    # Add header
    @data[0].each_with_index do |hash, x|
      sheet[0, x] = hash.first
    end
  
    # Add data
    @data.each_with_index do |row, y|
      row.each_with_index do |hash, x|
        sheet[y + 1, x] = hash.last
      end
    end
  end
  
  path = "tmp/data.xls"
  book.write path
  
  send_file(path, :disposition => 'attachment', :filename => File.basename(path))
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  
  include Churnobyl::Helpers
end


def db
  @db ||= Db.new
end

