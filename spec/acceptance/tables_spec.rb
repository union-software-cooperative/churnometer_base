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
      'startDate' => '2012-01-01',
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
      page.should have_content "230"
      page.should have_content "-23"
      page.should have_content "10147"
      page.should have_content "302"
      page.should have_content "-437"
      page.should have_content "-135"
      page.should have_content "10012"
      page.should have_content "9093"
      page.should have_content "631362.47"
    end
    within 'table#tableSummary tbody tr:nth-child(3)' do
      page.should have_content "Victorian Branch"
      page.should have_content "320"
      page.should have_content "-69"
      page.should have_content "22259"
      page.should have_content "361"
      page.should have_content "-413"
      page.should have_content "-52"
      page.should have_content "22207"
      page.should have_content "16649"
      page.should have_content "958618.40"
    end
    
    click_link "Paying" 
    within 'table#tablePaying tbody tr:nth-child(1)' do
      page.should have_content "General Branch"
      page.should have_content "10147"
      page.should have_content "302"
      page.should have_content "-437"
      page.should have_content "0"
      page.should have_content "0"
      page.should have_content "10012"
    end
    within 'table#tablePaying tbody tr:nth-child(3)' do
      page.should have_content "Victorian Branch"
      page.should have_content "22259"
      page.should have_content "361"
      page.should have_content "-413"
      page.should have_content "0"
      page.should have_content "0"
      page.should have_content "22207"
    end
    
    click_link "Victorian Branch"
    within '.filters' do
      page.should have_content "Victorian Branch"
    end
    
    click_link "Summary"
    within 'table#tableSummary tbody tr:nth-child(1)' do
      page.should have_content "Belinda Jacobi"
      page.should have_content "173"
      page.should have_content "-5"
      page.should have_content "10107"
      page.should have_content "178"
      page.should have_content "-187"
      page.should have_content "-9"
      page.should have_content "9962"
      page.should have_content "7242"
      page.should have_content "401376.06"
    end
    within 'table#tableSummary tbody tr:nth-child(2)' do
      page.should have_content "Chris Kalomiris"
      page.should have_content "0"
      page.should have_content "0"
      page.should have_content "3"
      page.should have_content "0"
      page.should have_content "0"
      page.should have_content "0"
      page.should have_content "3"
      page.should have_content "2"
      page.should have_content "81.20"
    end
    
  end
end