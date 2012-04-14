module Authorization
  
  def auth
    @auth ||=  Authorize.new Rack::Auth::Basic::Request.new(request.env)
  end
  
  def protected!
    unless auth.leader? || auth.user? || auth.lead? || auth.staff?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  
  class Authorize
    attr_accessor :auth
    
    def leader? 
      @leader
    end
    
    def lead?
      @lead
    end
    
    def staff?
      @staff
    end
    
    def user?
      @user
    end
    
    def initialize(auth)
      @auth = auth
      @leader = auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['leadership', 'fallout']
      @lead = auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['lead', 'growth']
      @user = auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['user', '']
      @staff = auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['staff', 'followup']
    end
  end
  
end
