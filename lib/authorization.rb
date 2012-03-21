module Authorization
  def leader?
    auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['leadership', 'fallout']
  end
  
  def lead?
    auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['lead', 'growth']
  end

  def user?
    auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['user', '']
  end

  def protected!
    unless leader? || user? || lead?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  
  def auth
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
  end
end
