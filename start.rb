require 'rubygems'
require 'sinatra'
require 'erb'
require 'pg'
require 'sass'

get '/' do
  erb :index  
end

post '/get_data' do
  @data = db.ex params[:sql]
  erb :summary
end

get '/get_data' do
  @data = db.ex params[:sql]
  erb :summary
end

get '/stylesheets/:name.css' do |name|
  scss name.to_sym, :style => :expanded
end


get '/summary' do
  @data = db.ex summary_sql
  erb :summary
end

def summary_sql
  xml = "<search><branchid>NG</branchid><status>1</status><status>14</status></search>"
  
  # org branchid companyid status lead area del hsr
  # nuwelectorate state feegroup
  
  <<-SQL 
    select * 
    from churnsummarydyn7('org', 
                          '2011-10-6', 
                          '2012-1-3',
                          true, 
                          '#{xml}'
                          )
  SQL
end

def db
  @db ||= Db.new
end

class Db
  def initialize
    @conn = PGconn.open(
      :host => "122.248.235.218",
      :port => "5432",
      :dbname => "churnobyl",
      :user => "churnuser",
      :password => "fcchurnpass"
    )
  end
  
  def ex(sql)
    @conn.exec(sql)
  end
  
end