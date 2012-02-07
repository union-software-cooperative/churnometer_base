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

