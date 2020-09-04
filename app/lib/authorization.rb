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
require "sinatra/base"
require "oauth2"

module Oauth2Authorization
  # Returns the class that will be instantiated to handle the authorisation functionality. The class
  # must follow Authorize's interface.
  def auth_class
    Oauth2Authorize
  end

  def oauth2_client(token_method = :post)
    OAuth2::Client.new(
      ENV['OAUTH2_CLIENT_ID'],
      ENV['OAUTH2_CLIENT_SECRET'],
      :site         => ENV['OAUTH2_PROVIDER'] || "http://doorkeeper-provider.herokuapp.com",
      :token_method => token_method,
    )
  end

  def access_token
    OAuth2::AccessToken.new(oauth2_client, session[:access_token], :refresh_token => session[:refresh_token])
  end

  def oauth2_redirect_uri
    ENV['OAUTH2_CLIENT_REDIRECT_URI']
  end

  def get_profile
    begin
      response = access_token.get("/me.json")
      @json = JSON.parse(response.body)
    rescue OAuth2::Error => @error
      not_authorised
    end
  end

  def auth
    @auth ||= auth_class().new(app(), get_profile)
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
    return_to = "?return_to=#{CGI::escape(request.path + "?" + request.query_string)}"
    redirect_url = URI.join(oauth2_redirect_uri, return_to).to_s
    puts "NOT AUTHORISED: " + redirect_url
    response['Cache-Control'] = "no-cache" #"public, max-age=0, must-revalidate"
    redirect oauth2_client.auth_code.authorize_url(:redirect_uri => redirect_url, :scope => 'profile')
  end
end


class Oauth2Authorize
  attr_accessor :auth
  attr_reader :role
  attr_reader :admin

  def initialize(churn_app, auth)
    @app = churn_app
    @auth = auth
    @authenticated = @auth.is_a?(Hash)
    @groups = @auth.dig('groups') || []
    @admin = admin?

    leadership_list = churn_app.config().element('leadership_list')&.simple_value || []

    @role =
      if leadership_list.include?(email)
        @app.roles['leadership']
      elsif @auth
        @app.roles['lead']
      else
        @app.unauthenticated_role
      end

    # @admin = @role.admin?
  end

  def is_member?(group)
    @groups.include?(group)# ? true : false
  end

  def authenticated?
    @authenticated# == true
  end

  def admin?
    is_member?(ENV['LDAP_ADMIN_GROUP'])
  end

  def profile
    auth['profile']
  end

  def name
    profile['given_name']
  end

  def email
    auth['email']
  end
end

module BasicAuthorization
  # Returns the class that will be instantiated to handle the authorisation functionality. The class
  # must follow Authorize's interface.
  def auth_class
    BasicAuthorize
  end

  def auth
    @auth ||= auth_class().new(app(), Rack::Auth::Basic::Request.new(request.env))
  end

  def protected!
    unless auth.authenticated?  && !auth.admin?
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

class BasicAuthorize
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
