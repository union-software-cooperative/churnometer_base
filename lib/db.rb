class Db
  def initialize
    @conn = PGconn.open(
      :host => "127.0.0.1",
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

