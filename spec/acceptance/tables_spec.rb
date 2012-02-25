require File.expand_path(File.dirname(__FILE__) + "/acceptance_helper")

class Churnobyl
  # Override authentication includes
  def leader?
    true
  end
  def protected!
  end

  # Override DataSql dates
  def query
    {
      'group_by' => 'branchid',
      'startDate' => '2012-02-01',
      'endDate'   => '2012-02-08',
      'column' => '',
      'interval' => 'none',
      Filter => {
        'status' => [1, 14]
      }
    }.rmerge(params)
  end
end

describe "Tables" do
  it "Has the expected data" do
    visit "/"
    
    page.should have_content("prototype")
    click_link "Summary"
    within 'table#tableSummary tbody tr:nth-child(1)' do
      page.should have_content "General Branch"
      page.should have_content "88"
      page.should have_content "-15"
      page.should have_content "10075"
      page.should have_content "189"
      page.should have_content "-252"
      page.should have_content "-63"
      page.should have_content "10012"
      page.should have_content "5803"
      page.should have_content "301272.14"
    end
    within 'table#tableSummary tbody tr:nth-child(2)' do
      page.should have_content "Victorian Branch"
      page.should have_content "94"
      page.should have_content "-1"
      page.should have_content "22216"
      page.should have_content "59"
      page.should have_content "-68"
      page.should have_content "-9"
      page.should have_content "22207"
      page.should have_content "2283"
      page.should have_content "94786.71"
    end
    
    click_link "Paying" 
    within 'table#tablePaying tbody tr:nth-child(1)' do
      page.should have_content "General Branch"
      page.should have_content "10075"
      page.should have_content "189"
      page.should have_content "-252"
      page.should have_content "0"
      page.should have_content "0"
      page.should have_content "10012"
    end
    within 'table#tablePaying tbody tr:nth-child(2)' do
      page.should have_content "Victorian Branch"
      page.should have_content "22216"
      page.should have_content "59"
      page.should have_content "-68"
      page.should have_content "0"
      page.should have_content "0"
      page.should have_content "22207"
    end
  end
end