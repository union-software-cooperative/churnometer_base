class Db
  def initialize
    @conn = PGconn.open(
      :host =>      Config['database']['host'],
      :port =>      Config['database']['port'],
      :dbname =>    Config['database']['dbname'],
      :user =>      Config['database']['user'],
      :password =>  Config['database']['password']
    )
  end
  
  def ex(sql)
    @conn.exec(sql)
  end
end

