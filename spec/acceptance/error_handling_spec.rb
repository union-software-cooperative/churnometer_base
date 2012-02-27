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
  before :each do
    # Don't send email when testing
    Pony.stub!(:mail)
  end

  # This spec leaves an ugly stacktrace behind.  Not sure how to silence it for this
  # spec
  it "shows stack trace" do
    Pony.should_receive(:mail)

    visit "/?startDate=20-01-01"
  
    page.should have_content "date/time field value out of range"    
  end
end