require File.expand_path(File.dirname(__FILE__) + "/acceptance_helper")


class AuthorizeOverride < Authorize
  def role
    app().roles.get_mandatory('leader')
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

  # Override authentication
  def protected!
  end
  
  def auth
    @auth ||=  AuthorizeOverride.new Rack::Auth::Basic::Request.new(request.env)
  end

  def churn_request_class
    ChurnRequestOverride
  end
end


describe "admin" do
  
  before :each do
    # Don't send email when testing
    Pony.stub!(:mail)
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
    
    click_link("Summary")
    within 'table#table-summary thead' do
      table_header_has "data entry", "total cards in", "cards in not followed up", "cards failed", "a1p started paying", "became stopped paying", "became stopped paying not followed up", "stopped paying followed up", "stopped paying resumed paying", "became rule59 not followed up", "transactions", "income posted", "income corrections"
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
      within "th:nth-child(#{i + 1})" do
        page.should have_content item
      end
    end
  end
end
