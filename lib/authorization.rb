module Authorization
  # Returns the class that will be instantiated to handle the authorisation functionality. The class
  # must follow Authorize's interface.
  def auth_class
    Authorize
  end

  def auth
    @auth ||= auth_class().new(app(), Rack::Auth::Basic::Request.new(request.env))
  end
  
  def protected!
    unless auth.authenticated?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  
end


class Authorize
  attr_accessor :auth
  attr_reader :role

  def initialize(churn_app, auth)
    @app = churn_app
    @auth = auth

    @role = 
      if @auth.provided?
        @app.roles[@auth.credentials.first]
      else
        nil
      end

    @role ||= @app.unauthenticated_role

    @authenticated = 
      auth.provided? && 
      auth.basic? && 
      auth.credentials && 
      @role.password_authenticates?(@auth.credentials.last)
  end

  def authenticated?
    @authenticated == true
  end
end
