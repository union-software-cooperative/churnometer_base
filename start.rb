require 'rubygems'
require 'sinatra'
require 'erb'
require 'pg'
require 'sass'
require 'ir_b'

get '/' do
  erb :index  
end

get '/get_data' do
  @defaults = defaults
  @data = db.ex params[:sql]
  erb :summary
end

get '/stylesheets/:name.css' do |name|
  scss name.to_sym, :style => :expanded
end

get '/summary' do
  @defaults = defaults
  @data = db.ex summary_sql
  erb :summary
end


def defaults
  {
    'group_by' => 'org',
    'startDate' => '2011-10-6',
    'endDate' => '2012-1-3',
    'filter' => {
      'branchid' => 'NG',
      'status' => [1, 14]      
    }
  }.merge(params)
end

# select displaytext from displaytext where attribute = 'org' and id='dpegg'

def summary_sql  
  xml = filter_xml defaults['filter']
  
  <<-SQL 
    select * 
    
    from churnsummarydyn8('#{defaults['group_by']}', 
                          '#{defaults['startDate']}', 
                          '#{defaults['endDate']}',
                          true, 
                          '#{xml}'
                          )
  SQL
end

def filter_xml(filters)
  # Example XML
  # <search><branchid>NG</branchid><org>dpegg</org><status>1</status><status>14</status></search>
  result = "<search>"
  filters.each do |k, v|
    if v.is_a?(Array)
      v.each do |item|
        result += "<#{k}>#{item}</#{k}>"
      end
    else
      result += "<#{k}>#{v}</#{k}>"
    end
  end
  
  if defaults['row_header_id']
    result += "<#{defaults['group_by']}>#{defaults['row_header_id']}</#{defaults['group_by']}>"
  end
  
  result += "</search>"
  result
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