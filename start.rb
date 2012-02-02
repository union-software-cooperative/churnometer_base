require 'rubygems'
require 'sinatra'
require 'erb'
require 'pg'

get '/summary' do
  @data = db.ex("select * from churnsummarydyn7('org', '2011-10-6', '2012-1-3',true, '<search><branchid>NG</branchid><status>1</status><status>14</status></search>')")
  erb :summary
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