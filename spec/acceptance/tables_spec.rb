require File.expand_path(File.dirname(__FILE__) + "/acceptance_helper")

# Override authentication includes
class Churnobyl
  def leader?
    true
  end
  
  def protected!
  end
end

describe "Tables" do
  it "Has the expected data" do
    visit "/"
    save_and_open_page
    
    page.should have_content("prototype")
    click_link "Summary"
    # within 'table#tableSummary tbody tr:nth-child(1)' do
    #   page.should have 
    # end
  end
end