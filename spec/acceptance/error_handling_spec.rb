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

require File.expand_path(File.dirname(__FILE__) + "/acceptance_helper")

describe "Not found" do
  it "shows appropriate error" do
    visit "/something-that-does-not-exist"
   
    page.should have_content "Route does not exist"
  end
end

describe "Internal error" do
  before :each do
    # Don't send email when testing
    Pony.stub!(:mail)

    class ChurnometerApp
      def email_on_error?
        true
      end

      def email_on_error_from
        "churnometer-error-handling-rspec@freechange.com.au"
      end

      def email_on_error_to
        "churnometer-error-handling-rspec@freechange.com.au"
      end

      def validate_email
        # The test provides its own email settings, so the email config doesn't need to be verified.
      end
    end

    class AuthorizeOverride < Authorize
      def role
        @app.roles.get_mandatory('leadership')
      end
    end

    class Churnobyl

      # Override authentication
      def protected!
      end
      
      def auth_class
        AuthorizeOverride
      end
    end
  end

  # This spec leaves an ugly stacktrace behind.  Not sure how to silence it for this
  # spec
  it "shows stack trace and sends mail" do
    Pony.should_receive(:mail)

    visit "/?startDate=33-33-33"
  
    page.should have_content "invalid date"
  end
end
