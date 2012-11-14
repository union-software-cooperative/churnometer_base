#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange) 
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.

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
      not_authorised
    end
  end
  
  def admin!
    unless auth.authenticated? && auth.admin?
      not_authorised
    end
  end
  
  def not_authorised
    response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
    throw(:halt, [401, "Not authorized\n"])
  end
  
end


class Authorize
  attr_accessor :auth
  attr_reader :role
  attr_reader :admin

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
    
    @admin = @role.admin?

    @authenticated = 
      auth.provided? && 
      auth.basic? && 
      auth.credentials && 
      @role.password_authenticates?(@auth.credentials.last)
  end

  def authenticated?
    @authenticated == true
  end
  
  def admin?
    @admin
  end
end
