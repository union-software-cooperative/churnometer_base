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
    
    page.should have_select('group_by', :options => ['Data Entry'])
    
    select "Data Entry", :from => "group_by"
    click_button "Refresh"
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"

    test_app().roles.get_mandatory($testing_role).summary_data_tables.each do |table|
      click_link(table.display_name)

      page.should have_css("table#table-#{table.display_name.downcase} thead")

      within "table#table-#{table.display_name.downcase} thead" do
        tables = test_app().roles.get_mandatory($testing_role).summary_data_tables
        table_headers = table.column_names.collect do |col_name|
          test_app().col_names[col_name]
        end

        # tbd: infer first entry from 'group by'
        table_header_has ['data entry'] + table_headers.compact
      end
    end
    
    drill_down_into_data_entry
  end
  
  def drill_down_into_data_entry
    within 'table#table-summary' do
      click_link "Reception"
    end
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"
    
    page.should have_content "Data Entry: Reception"
  end
  
  it "has a stopped paying table" do
    visit "/"
    
    click_link("Stopped")
    within 'table#table-stopped thead' do
      
      table_header_has "branch", "stopped paying at start date", "became stopped paying", "became stopped paying not followed up", "stopped paying followed up", "stopped paying resumed paying", "stopped paying transfers in", "stopped paying transfers out", "stopped paying at end date", "became rule59 not followed up"
    end
    within 'table#table-stopped tfoot' do
      row_has "", %w{3335 196 179 -317 -20 0 0 3194 89}
    end
  end
  
  it "can drill into stopped paying" do
     visit "/"

      click_link("Stopped")
      within('table#table-stopped tbody tr:nth-child(1)') do
        click_link "94"
      end
      within('table#table-membersummary tbody tr:nth-child(1)') do 
        row_has "General Branch", "20 April 2012", "Taiwa, Lionel (NG053785)"
      end
      
      click_link("Follow up")
      within 'table#table-followup thead' do
        table_header_has "branch", "changedate", "memberid", "member", "current status", "follow up notes", "payment type", "current contact detail", "current site", "current employer", "payroll/hr contact", "current payment status", "new organiser"
      end
  end
  
  it "shows employer payment status" do
    visit "/?column=&startDate=14+August+2011&endDate=26+April+2012&group_by=employerid&interval=none&f%5Bbranchid%5D=NG&f%5Blead%5D=afalconer&f%5Borg%5D=borders&lock%5Bcompanyid%5D="
    
    click_link("Remittance")
    within 'table#table-remittance thead' do
      table_header_has "employer", "a1p at end date", "paying at end date", "payment type", "current paid to date", "current payment status"
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
        $stderr.puts element.text
        $stderr.puts "*" + item
        page.should have_content item
      end
    end
  end
end
