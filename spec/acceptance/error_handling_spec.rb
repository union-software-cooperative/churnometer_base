require File.expand_path(File.dirname(__FILE__) + "/acceptance_helper")

class Churnobyl
  # Override authentication includes
  def leader?
    true
  end
  
  def protected!
  end
end

describe "Not found" do
  it "shows appropriate error" do
    visit "/something-that-does-not-exist"
   
    page.should have_content "Route does not exist"
  end
end

describe "Internal error" do
  # This spec leaves an ugly stacktrace behind.  Not sure how to silence it for this
  # spec
  it "shows stack trace" do
    visit "/?startDate=20-01-01"
  
    page.should have_content "date/time field value out of range"
    page.should have_content "/?startDate=20-01-01"
    page.should have_content '{"startDate"=>"20-01-01", "splat"=>[], "captures"=>[#]}'
    page.should have_content "select * from churnsummarydyn19( 'memberfacthelperpaying2', 'branchid', '', '20-01-01', '2012-02-27', true, '114' )"
    page.should have_content "/churnobyl/lib/db.rb"
  end
end