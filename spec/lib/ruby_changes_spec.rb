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