require File.expand_path(File.dirname(__FILE__) + "/acceptance_helper")


class AuthorizeOverride < Authorize
  def staff?
    true
  end
end

class ChurnRequestOverride < ChurnRequest
  # Override ChurnDB dates
  def query_defaults
    super.rmerge({
      'startDate' => '2012-02-01',
      'endDate'   => '2012-03-31',
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

  # Override user request with overridden auth class and ChurnDBDiskClass
  def cr
    @cr ||= ChurnRequestOverride.new request.url, auth, params, ChurnDBDiskCache.new
  end
end


describe "admin" do
  
  before :each do
    # Don't send email when testing
    Pony.stub!(:mail)
  end
  
  it "Admin can login" do
    # This doesn't really test the basic auth - TODO
    visit "/"
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"
  end
  
  it "has a support support staff group by option that works" do
    visit "/"
    
    page.should have_select('group_by', :options => ['Support Staff'])
    
    within('#filter') do
      select "Support Staff", :from => "group_by"
      fill_in 'startDate', :with => '1 February 2012'
      fill_in 'endDate', :with => '31 March 2012'
    end
    click_button "Refresh"
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"
    
    drill_down_into_support_staff

  end
  
  def drill_down_into_support_staff
    click_link "Stopped"
    within 'table#table-stopped' do
      click_link "Audrey Zugaro"
    end
    
    page.should have_content("Start Date") 
    page.should have_content("End Date") 
    page.should have_content("Group by") 
    page.should have_content("Running total") 
    page.should have_no_content "Error"
    
    page.should have_content "Support Staff: Audrey Zugaro"
  end
  
  
  it "has a custom summary" do
    visit "/"
    
    click_link("Summary")
    within 'table#table-summary thead' do
      table_header_has "support staff", "month beginning", "cards in not followed up", "became stopped paying not followed up", "became rule59 not followed up", "paying at end date", "a1p at end date", "stopped paying at end date"
    end
    within 'table#table-summary tfoot' do
      row_has "", "", "618", "557", "140" 
    end
  end
  
  it "can drill into stopped paying" do
     visit "/"

      click_link("Stopped")
      within('table#table-stopped tbody tr:nth-child(3)') do
        click_link "15"
      end
      within('table#table-followup tbody tr:nth-child(1)') do 
        row_has "Darinka Matijasevic", "23 February 2012", "NQ052808", "Sciacca, Sue (NQ052808)"
      end
  end
  
  it "can show who became rule 59 and isn't followed up" do
    visit "/"
    
    within('#filter') do
      select "Off", :from => "interval"
      fill_in 'startDate', :with => '1 February 2012'
      fill_in 'endDate', :with => '31 March 2012'
    end
    click_button "Refresh"
    
    
    within 'table#table-summary tfoot td:nth-child(4)' do
      click_link "140"
    end
    
    click_link "Follow up"
  
    within 'table#table-followup thead' do
      table_header_has "support staff", "changedate", "memberid", "member", "current status", "follow up notes", "payment type", "current contact detail", "old site", "old employer", "old organiser"
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