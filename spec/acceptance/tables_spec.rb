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

class ChurnRequestOverride < ChurnRequest
  # Override ChurnDB dates
  def query_defaults
    super.rmerge({
      'startDate' => '2011-08-14',
      'endDate'   => '2012-10-04',
      'interval'  => 'none'
    })
  end
end

class AuthorizeOverride < Authorize
  attr_accessor :role_override

  def role
#    p @app.roles[Churnobyl.role_override]
    @app.roles[Churnobyl.role_override] || @app.roles.get_mandatory('leadership')
  end
end

class Churnobyl
  def self.churnometer_app_config_io
    StringIO.new(config_text_override() || $regression_config_str)
  end
  
  # Override authentication
  def protected!
  end

  # Some output that relies on the config being reloaded won't change correctly unless caching is
  # disabled.
  def allow_http_caching?
    false
  end

  def auth_class
    AuthorizeOverride
  end

  def churn_request_class
    ChurnRequestOverride
  end

  def reload_config_on_every_request?
    true
  end

  def self.config_text_override
    @config_text 
  end

  def self.role_override
    @role_override
  end

  # 'role' is a role id.
  def self.with_role(role, &block)
    @role_override = role
    yield
    @role_override = nil
  end

  def self.with_config(text, &block)
    @config_text = text

    # An app is instantiated only so the block can read config settings. The instance is not the same
    # instance that Capybara will be using.
    reference_app = 
      ChurnometerApp.new(:development, StringIO.new(@config_text), churnometer_app_config_io_desc())

    yield reference_app

    @config_text = nil
  end
end

# Requests on a local machine can take a long time.
Capybara.configure do |config|
  config.default_wait_time = 60
end

shared_examples "roles" do |_class|
  it "is empty when first created" do
    collection_class.new.should be_empty
  end
end

describe 'App under role configuration' do
  it 'should display the growth target when enabled for role' do
    Churnobyl.with_role('leadership') do
      visit "/"

      page.has_css?('#card_target')
    end
  end

  it 'should omit the growth target when disabled for role' do
    Churnobyl.with_role('leadership') do
      no_target_config = 
        $regression_config_str.gsub(/show_target_calculation:.+/, 'show_target_calculation: false')
      
      Churnobyl.with_config(no_target_config) do |reference_app|
        visit '/'
        
        page.has_no_css?('#card_target')
      end
    end
  end
end

describe "Tables" do
  it "Has the expected data" do
    visit "/"
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"
    
    check_home_summary

    click_button "Refresh"
    check_home_summary

    drill_down_into_branch
    drill_down_into_lead_organiser
    drill_down_into_organiser
  end
  
  it "Can group by month" do
    visit "/"
    
    select "Weekly", :from => "Running total"
    click_button "Refresh"
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total")
    page.should have_no_content "Error"
    page.should have_no_content "LINE CHART SHOULD REPLACE THIS DIV"
    
    select "Monthly", :from => "Running total"
    click_button "Refresh"
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total")
    page.should have_no_content "Error"
    page.should have_no_content "LINE CHART SHOULD REPLACE THIS DIV"
  end
  
  it "Can drill down into a member" do
    visit "/"
    click_link "Summary"

    within 'table#table-summary tbody tr:nth-child(1)' do
      click_link "63"
    end
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total")
    page.should have_no_content "Error"
  end
  
  it "Displays transfer warning" do
    visit "/?group_by=org&startDate=14 August 2011&endDate= 4 October 2012&interval=none&f!0[branchid]=b2&f[lead]=l2"
    
    within '#filters' do
      page.should have_content "Branch: Warehousing"
      page.should have_content "Lead Organiser: Djura Elango"
    end
    
    within('#filter') do
      fill_in 'startDate', :with => '14 August 2011'
      fill_in 'endDate', :with => '22 March 2012'
    end
    click_button "Refresh"
    
    within('#card_target') do
      page.should have_content "WARNING: These results are influenced by transfers. See the transfer tab."
    end
    
    click_link "Transfers"
    within('table#transferDates tbody tr:nth-child(4)') do
      row_has "6 December 2011", %w{[before 13 4 after]}
    end
    
    click_link "sites as assigned at the end of the period"
    within '#filters' do
      page.should have_content "Any time during the period"
      page.should have_content "22 March 2012"
    end
    
    within('#card_target') do
      page.should have_no_content "WARNING: These results are influenced by transfers. See the transfer tab."
    end
    
    click_link "Paying"
    within 'table#table-paying tfoot' do
      row_has "", %w{148 32 -19 1 -1 161}
    end
    
    within '#filters' do
      choose 'constrain_start'
    end
    click_button 'Refresh'
    
    click_link "Paying"
    within 'table#table-paying tfoot' do
      row_has "", %w{191 27 -19 0 -1 198}
    end
    
    # Can drill down to members held by organiser the start but not at the end
    within 'table#table-paying tbody tr:nth-child(1) td:nth-child(7)' do
      # beware if any of the first 7 rows change their name, the list will be 
      # reordered and subsequent tests will fail
      click_link "2"
    end
    
    within '#filters' do
      page.should have_content "Members: paying at end date"
    end
    
    # dbeswick: failure of this record to be at index 1 can indicate a failure in the orderby clause in
    # the detail_static_friendly query.
    click_link "Member Summary"
    within 'table#table-membersummary tbody tr:nth-child(1)' do
      row_has "Abigail's Store", "27 January 2012", "McIvor, Maja (m18146)", %w{ Paying Paying Paying Abigail's Abigail's Abigail's }
    end
  end
  
  it "can show paying members at start date" do
    visit "/?group_by=companyid&startDate=14%20August%202011&endDate=22%20March%202012&interval=none&f!0[branchid]=b2&f!0[lead]=l2&site_constraint=start"
    
    
    click_link "Paying"
    within 'table#table-paying tbody tr:nth-child(1)  td:nth-child(2)' do
      click_link "2"
    end
    
    click_link "Member Summary"
    within 'table#table-membersummary tbody tr:nth-child(1)' do
      row_has "Abigail's Store", "7 August 2011", "McIvor, Maja (m18146)","", "Paying", "Paying","", "Abigail's Store", "Abigail's Store"
    end
  end
  
  
  def check_home_summary 
    click_link "Summary"
    within 'table#table-summary tbody tr:nth-child(1)' do
      row_has "Construction", %w{55 -8 103 63 -46 17 120 -28 152 50380.59}
    end
    within 'table#table-summary tbody tr:nth-child(2)' do
      row_has "Warehousing", %w{77 -6 215 90 -48 42 257 -21 287 124292.80}
    end
    
    click_link "Paying" 
    within 'table#table-paying tbody tr:nth-child(1)' do
      row_has "Construction", %w{103 63 -46 0 0 120}
    end
    within 'table#table-paying tbody tr:nth-child(2)' do
      row_has "Warehousing", %w{215 90 -48 0 0 257}
    end
  end
  
  def drill_down_into_branch
    click_link "Warehousing"
    within '#filters' do
      page.should have_content "Branch: Warehousing"
    end
    
    click_link "Summary"
    within 'table#table-summary tbody tr:nth-child(2)' do
      row_has "Djura Elango", %w{53 -5 135 62 -31 31 140 -11 240 70204.88}
    end
    within 'table#table-summary tbody tr:nth-child(3)' do
      row_has "Gabriela Gear", %W{17 0 43 20 -13 7 107 -8 126 43188.87}
    end
    
    click_link "Paying" 
    within 'table#table-paying tbody tr:nth-child(2)' do
      row_has "Djura Elango", %w{135 62 -31 97 -123 140}
    end
    within 'table#table-paying tbody tr:nth-child(3)' do
      row_has "Gabriela Gear", %w{43 20 -13 116 -59 107}
    end
  end
  
  def drill_down_into_lead_organiser
    click_link "Djura Elango"
    within '#filters' do
      page.should have_content "Branch: Warehousing"
      page.should have_content "Lead Organiser: Djura Elango"
    end
    
    click_link "Summary"
    within 'table#table-summary tbody tr:nth-child(1)' do
      row_has "Alexandrus Anzaldi", %w{1 0 10 2 -1 1 12 -1 16 6458.68}      
    end
    within 'table#table-summary tbody tr:nth-child(2)' do
      row_has "Deepika Dume", %w{2 0 10 8 -5 3 34 -1 42 15208.01}
    end
    
    click_link "Paying" 
    within 'table#table-paying tbody tr:nth-child(1)' do
      row_has "Alexandrus Anzaldi", %w{10 2 -1 8 -7 12}      
    end
    within 'table#table-paying tbody tr:nth-child(2)' do
      row_has "Deepika Dume", %w{10 8 -5 34 -13 34}
    end
  end
  
  def drill_down_into_organiser
    click_link "Laurie Magdoza" 
    within '#filters' do
      page.should have_content "Branch: Warehousing"
      page.should have_content "Lead Organiser: Djura Elango"
      page.should have_content "Organiser: Laurie Magdoza"
    end
    click_link "Summary"
    within 'table#table-summary tbody tr:nth-child(8)' do
      row_has "Garner's Store", %w{5 -1 3 4 -1 3 0 0 6 1075.30}
    end
    within 'table#table-summary tbody tr:nth-child(16)' do
      row_has "Lincoln's Store", %w{2 0 6 1 0 1 0 0 7 1074.10}
    end
    
    click_link "Paying" 
    within 'table#table-paying tbody tr:nth-child(8)' do
      row_has "Garner's Store", %w{3 4 -1 0 -6 0}
    end
    within 'table#table-paying tbody tr:nth-child(16)' do
      row_has "Lincoln's Store", %w{6 1 0 0 -7 0}
    end
  end
 
  
  def row_has(*items)
    items.flatten.each_with_index do |item, i|
      within "td:nth-child(#{i + 1})" do
        page.should have_content item
      end
    end
  end
end
