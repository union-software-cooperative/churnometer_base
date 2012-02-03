module Churnobyl
  module Authorization
    def leader?
      auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['leader', 'adminpass']
    end

    def user?
      auth.provided? && auth.basic? && auth.credentials && auth.credentials == ['user', '']
    end

    def protected!
      unless leader? || user?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end
    
    def auth
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    end
  end
end
