module Authorization
  
  def auth
    @auth ||=  Authorize.new Rack::Auth::Basic::Request.new(request.env)
  end
  
  def protected!
    unless auth.leader? || auth.user? || auth.lead? || auth.staff? || auth.admin?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  
end


class Authorize
  attr_accessor :auth
  
  def admin? 
    @admin ||= auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['admin', 'letmein']
    @leader = @admin
  end
  
  def leader? 
    @leader ||= auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['leadership', 'fallout']
  end
  
  def lead?
    @lead ||= auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['lead', 'growth']
  end
  
  def staff?
    @staff ||= auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['staff', 'followup']
  end
  
  def user?
    @user ||= auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['user', '']
  end
  
  def initialize(auth)
    @auth = auth
  end
end