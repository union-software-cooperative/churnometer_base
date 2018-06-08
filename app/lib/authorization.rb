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

  # ?client_id=8052fa6780844bc36b816f1d077fc54c15b678c9322ed747b1f4d38a336754db&redirect_uri=http%3A%2F%2Fwww%3A9292%2Foauth2-callback&response_type=code&scope=profile
  # http://www:9292/oauth2-callback?code=04cc6aaeae6d3cae7577c7394b64964b2ce3b8f7b714a0f4c5f95fc88b91db48
  Sinatra::Base.get '/oauth2-callback' do
    return_to = params['return_to'] ? params['return_to'] : '/'

    redirect_url = URI.join(oauth2_redirect_uri, "?return_to=#{CGI::escape(return_to)}").to_s
    puts "CALLBACK: " + redirect_url
    new_token = oauth2_client.auth_code.get_token(params[:code], :redirect_uri => redirect_url)
    session[:access_token]  = new_token.token
    session[:refresh_token] = new_token.refresh_token
    response['Cache-Control'] = "no-cache"

    redirect CGI::unescape(return_to)
  end

  Sinatra::Base.get '/logout' do
    session.clear
    redirect ENV['OAUTH2_PROVIDER'] + "/logout"
  end

  Sinatra::Base.get '/account' do
    session.clear
    redirect ENV['OAUTH2_PROVIDER']
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
    @auth = auth['ldap']
    @authenticated = @auth.is_a?(Hash)
    @groups = @auth.dig('groups') || []
    @admin = admin?

    @role =
      if is_member?("CN=Churnometer_Leadership,CN=Users,DC=nuw,DC=org,DC=au")
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

  def name
    @auth['name']
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
