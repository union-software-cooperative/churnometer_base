require 'rubygems'
require 'bundler/setup'

require 'sinatra'

require 'pg'
require 'sass'
require 'erb'
require 'uri'
require 'ir_b'


# Short names to help shorten URL
FilterNames = "fn"
Filter = "f"

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
  erb :summary
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  
  def groups_by_collection
    [
      ["branchid", "Branch"],
      ["lead", "Lead Organizer"],
      ["org", "Organizer"],
      ["areaid", "Area"],
      ["companyid", "Work Site"],
      ["industryid", "Industry"],
      ["del", "Delegate Training"],
      ["hsr", "HSR Training"],
      ["nuwelectorate", "Electorate"],
      ["state", "State"],
      ["feegroup", "Fee Group"]
    ]
  end
  
  def drill_down(row)
    row_header_id = row['row_header_id']
    row_header = row['row_header']
    URI.escape "#{Filter}[#{@defaults['group_by']}]=#{row_header_id}&#{FilterNames}[#{row_header_id}]=#{row_header}"
  end
  
  def next_group_by
    hash = {
      'branchid'      => 'lead',
      'lead'          => 'org',
      'org'           => 'companyid',
      'state'         => 'area',
      'area'          => 'companyid',
      'feegroup'      => 'companyid',
      'nuwelectorate' => 'org',
      'del'           => 'companyid',
      'hsr'           => 'companyid',
      'companyid'     => 'companyid'
    }
    
    URI.escape "group_by=#{hash[defaults['group_by']]}"
  end
  
  def filter_names
    params[FilterNames] || []
  end
end


def defaults
  {
    'group_by' => 'branchid',
    'startDate' => '2011-10-6',
    'endDate' => '2012-1-3',
    Filter => {
      'status' => [1, 14]      
    }
  }.rmerge(params)
end

# select displaytext from displaytext where attribute = 'org' and id='dpegg'

def summary_sql  
  xml = filter_xml defaults[Filter]
  
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

module HashRecursiveMerge
  def rmerge!(other_hash)
    merge!(other_hash) do |key, oldval, newval| 
        oldval.class == self.class ? oldval.rmerge!(newval) : newval
    end
  end

  def rmerge(other_hash)
    r = {}
    merge(other_hash)  do |key, oldval, newval| 
      r[key] = oldval.class == self.class ? oldval.rmerge(newval) : newval
    end
  end
end


class Hash
  include HashRecursiveMerge
end