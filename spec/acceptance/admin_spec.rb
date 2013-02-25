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

$testing_role = 'leadership'

def test_app
  Churnobyl.server_lifetime_churnometer_app
end

describe "admin" do
  
  before :each do
    # Don't send email when testing
    Pony.stub!(:mail)

    class AuthorizeOverride < Authorize
      def role
        @app.roles.get_mandatory($testing_role)
      end
    end

    class ChurnRequestOverride < ChurnRequest
      # Override ChurnDB dates
      def query_defaults
        super.rmerge({
                       'startDate' => '2012-04-05',
                       'endDate'   => '2012-04-26',
                     })
      end
    end

    class Churnobyl
      def self.churnometer_app_site_config_io
        StringIO.new($regression_config_str)
      end

      def testing?
        true
      end

      # Override authentication
      def protected!
      end
      
      def auth_class
        AuthorizeOverride
      end

      def churn_request_class
        ChurnRequestOverride
      end
    end
  end
  
  it "Leader can login" do
    # This doesn't really test the basic auth - TODO
    visit "/"
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"
  end
  
  it "has a data entry group by option that works" do
    visit "/"

    page.should have_select('group_by', :with_options => ['Data Entry'])
    
    select "Data Entry", :from => "group_by"
    click_button "Refresh"
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"

    page.should have_selector(:link, :text=>"Summary")
    page.find(:link, :text=>"Summary").click

    page.should have_css("table#table-summary thead")

    within "table#table-summary thead" do
      table_header_has
      ['data entry',
       'new applications (total)',
      'applications exited w/out payment',
      'paying at start date',
      'started paying',
      'ceased paying',
      'paying net',
      'paying at end date',
      'left stopped paying cycle (exited)',
      'unique contributors',
      'income net']
    end
  end
  
  it "has a stopped paying table" do
    visit "/"
    
    select "Branch", :from => "group_by"
    click_button "Refresh"
    
    click_link("Stopped")
    within 'table#table-stopped thead' do
      
      table_header_has "branch", "stopped paying at start date", "entered stopped paying cycle", "entered stopped paying cycle (pending resolution)", "left stopped paying cycle (exited)", "left stopped paying cycle (resumed paying)", "stopped paying transfers in", "stopped paying transfers out", "stopped paying at end date"
    end
    within 'table#table-stopped tfoot' do
      row_has "", %w{24 	4 	1 	-1 	0 	0 	0 	27}
    end
  end
  
  it "can drill into stopped paying" do
     visit "/"

      click_link("Stopped")
      within('table#table-stopped tbody tr:nth-child(1)') do
        click_link "6"
      end
      within('table#table-membersummary tbody tr:nth-child(1)') do 
        row_has "Construction", "19 March 2012", "Fanene, Edan (m45268)"
      end
  end
  
  def row_has(*items)
    items.flatten.each_with_index do |item, i|
      within "td:nth-child(#{i + 1})" do
        page.should have_content item
      end
    end
  end
  
  def table_header_has(*items)
    items.flatten.each_with_index do |item, i|
      within "th:nth-child(#{i + 1})" do |element|
        page.should have_content item
      end
    end
  end
end
