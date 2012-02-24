require File.expand_path('../../spec_helper.rb', __FILE__)

describe "Ruby changes" do

  describe Hash do
    it "deep merges" do 
      hash =                {one: {two: 'original', something: "else"}}
      result = hash.rmerge( {one: {two: 'new'                        }})
      result.should ==      {one: {two: 'new',      something: "else"}}
    end

    it "deep merges on self" do 
      hash =          {one: {two: 'original', something: "else"}}
      hash.rmerge!(   {one: {two: 'new'                        }})
      hash.should ==  {one: {two: 'new',      something: "else"}}
    end
  end
  
end