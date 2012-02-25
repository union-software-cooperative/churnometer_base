require File.expand_path(File.dirname(__FILE__) + "/acceptance_helper")

class Churnobyl
  # Override authentication includes
  def leader?
    true
  end
  
  def protected!
  end
end

class DataSqlProxy
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
    
    check_home_summary

    click_button "Refresh"
    check_home_summary

    drill_down_into_branch
    drill_down_into_lead_organiser
    drill_down_into_organiser
  end
  
  def check_home_summary 
    click_link "Summary"
    within 'table#tableSummary tbody tr:nth-child(1)' do
      row_has "General Branch", %w{230 23 10147 302 -437 -135 10012 9093 631362.47}
    end
    within 'table#tableSummary tbody tr:nth-child(3)' do
      row_has "Victorian Branch", %w{320 -69 22259 361 -413 -52 22207 16649 958618.40}
    end
    
    click_link "Paying" 
    within 'table#tablePaying tbody tr:nth-child(1)' do
      row_has "General Branch", %w{10147 302 -437 0 0 10012}
    end
    within 'table#tablePaying tbody tr:nth-child(3)' do
      row_has "Victorian Branch", %w{22259 361 -413 0 0 22207}
    end
  end
  
  def drill_down_into_branch
    click_link "Victorian Branch"
    within '#filters' do
      page.should have_content "Branch: Victorian Branch"
    end
    
    click_link "Summary"
    within 'table#tableSummary tbody tr:nth-child(1)' do
      row_has "Belinda Jacobi", %w{173 -5 10107 178 -187 -9 9962 7242 401376.06}
    end
    within 'table#tableSummary tbody tr:nth-child(2)' do
      row_has "Chris Kalomiris", %W{0 0 3 0 0 0 3 2 81.20}
    end
    
    click_link "Paying" 
    within 'table#tablePaying tbody tr:nth-child(1)' do
      row_has "Belinda Jacobi", %w{10107 178 -187 4 -140 9962}
    end
    within 'table#tablePaying tbody tr:nth-child(2)' do
      row_has "Chris Kalomiris", %w{3 0 0 0 0 3}
    end
  end
  
  def drill_down_into_lead_organiser
    click_link "Belinda Jacobi"
    within '#filters' do
      page.should have_content "Branch: Victorian Branch"
      page.should have_content "Lead Organiser: Belinda Jacobi"
    end
    
    click_link "Summary"
    within 'table#tableSummary tbody tr:nth-child(1)' do
      row_has "Adam Auld", %w{15 -1 1505 20 -27 -7 1498 1171 57203.55}      
    end
    within 'table#tableSummary tbody tr:nth-child(2)' do
      row_has "Belinda Jacobi", %w{8 -3 1166 78 -27 51 1215 1062 54700.28}
    end
    
    click_link "Paying" 
    within 'table#tablePaying tbody tr:nth-child(1)' do
      row_has "Adam Auld", %w{1505 20 -27 0 0 1498}
    end
    within 'table#tablePaying tbody tr:nth-child(6)' do
      row_has "Gayle Burmeister", %w{613 13 -15 4 -7 608}
    end
  end
  
  def drill_down_into_organiser
    click_link "Gayle Burmeister" 
    within '#filters' do
      page.should have_content "Branch: Victorian Branch"
      page.should have_content "Lead Organiser: Belinda Jacobi"
      page.should have_content "Organiser: Gayle Burmeister"
    end
    click_link "Summary"
    within 'table#tableSummary tbody tr:nth-child(1)' do
      row_has "3D Geoshapes Australia Pty Ltd", %w{0 0 1 0 0 0 1 1 40.60}
    end
    within 'table#tableSummary tbody tr:nth-child(15)' do
      row_has "Charles Parsons (Vic) P/L", %w{7 0 2 4 0 4 0 6 196.23}
    end
    
    click_link "Paying" 
    within 'table#tablePaying tbody tr:nth-child(1)' do
      row_has "3D Geoshapes Australia Pty Ltd", %w{1 0 0 0 0 1}
    end
    within 'table#tablePaying tbody tr:nth-child(15)' do
      row_has "Charles Parsons (Vic) P/L", %w{2 4 0 0 -6 0}
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