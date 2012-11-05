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

require './lib/churn_presenters/helpers.rb'
require './lib/settings.rb'

class ChurnPresenter_Target
  
  include ChurnPresenter_Helpers
  include Settings
  
  def initialize(app, request)
    @request=request
    @app=app
  end
  
  def weeks
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate']) + 1
    
    (Float(end_date - start_date) / 7).round(1)
  end
  
  def growth
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate']) + 1
  
    start_count = paying_start_total
    
    started = 0
    @request.data.each { | row | started += row['paying_real_gain'].to_i }
    
    stopped = 0
    @request.data.each { | row | stopped += row['paying_real_loss'].to_i }
    
    end_count = start_count + stopped + started
    
    start_date == end_date || start_count == 0 ? Float(1/0.0) : Float((((Float(end_count) / Float(start_count)) **  (365.0/(Float(end_date - start_date)))) - 1) * 100).round(1)
  end

  def get_cards_in_growth_target
    
    # the number of people who stopped paying
    stopped = 0
    @request.data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    @request.data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count of a1p people who start paying
    conversions = 0
    @request.data.each { | row | conversions -= row['a1p_to_paying'].to_i }
    
    # count the joiners who fail to convert to paying
    failed = 0 
    @request.data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    # count the joiners who fail to convert to paying
    cards = 0 
    @request.data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate']) + 1
    
    cards_per_week = 0.0
    if start_date != end_date  
      growth = Float((paying_start_total + paying_transfers_total)) * 0.1 / 365 * Float(end_date - start_date) # very crude growth calculation - But I don't think CAGR makes sense, the formula would be # growth = (((10% + 1) ^ (duration/365) * start) - start) 
       
      # METHOD 1.  for every sign up, we only convert some to paying
      # growth = conversions == 0 || cards == 0 ? growth : growth * (cards/conversions) # if we got no conversions or cards, then don't worry about the ratio and just go for cards in - bad bad bad.
      
      # METHOD 2. For every card we get in, there is some that never start paying 10 vs 2.  If we get 20 we'd expect 4 to not start paying.
      # To get the 4 we multiple growth target number failed/cards * target + target 
      # growth += (cards == 0 ? 0 : failed/cards * growth)  
      
      # METHOD 3.  Maybe I'm counting the conversion ratio twice in Method 1 and 2.  
      # The conversion ratio may be already included in the cards we need to hold our ground
      # See + failed in equation below, so I should leave the raw growth figure alone
      # Method 1 and 2 also leave the equation vulnerable to crazy volatility
       
      # to hold our ground we need to recruit the same number as those that stopped, 
      # less those that historically resume paying on their own (these are freebies)
      # plus those that new cards that failed to start paying
      # plus a certain amount to achieve some growth figure.  The growth figure should reflect
      cards_per_week = Float((Float(stopped - resume + failed + growth) / Float(end_date - start_date) * 7 )).round(1) 
    end
    
    cards_per_week
  end

  def get_cards_in_target
    
    # the number of people who stopped paying
    stopped = 0
    @request.data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    @request.data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count the joiners who fail to convert to paying
    failed = 0 
    @request.data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate']) + 1
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float((Float(stopped - resume + failed) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end

  def getmath_get_cards_in_target

     # the number of people who stopped paying
     stopped = 0
     @request.data.each { | row | stopped -= row['paying_real_loss'].to_i }

     # count the people who start paying without giving us a card
     # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
     resume = 0 
     @request.data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 

     paying_real_gain = 0 
     @request.data.each { | row | paying_real_gain += row['paying_real_gain'].to_i } 
     
     a1p_to_paying = 0 
     @request.data.each { | row | a1p_to_paying += row['a1p_to_paying'].to_i } 
     
     # count the joiners who fail to convert to paying
     failed = 0 
     @request.data.each { | row | failed -= row['a1p_to_other'].to_i }

     start_date = Date.parse(@request.params['startDate'])
     end_date = Date.parse(@request.params['endDate']) + 1

     cards_per_week = 0.0
     weeks = 0
     cards = 0 
     cards_per_week = 0
     if start_date != end_date 
       weeks =  Float(end_date - start_date) / 7
       cards = Float(stopped - resume + failed)
       cards_per_week = Float(cards / weeks ).round(1)
     end

     "#{cards.round(0)} cards needed (#{stopped} #{col_names['paying_real_loss']} + #{failed} #{col_names['a1p_to_other']} - #{resume} resumed paying without a card (#{paying_real_gain} #{col_names['paying_real_gain']} - #{-a1p_to_paying} #{col_names['a1p_to_paying']}) ) / #{weeks.round(1)} weeks = #{cards_per_week}  cards per week"
   end

  def get_cards_in
    
    # the number of people who stopped paying
    cards = 0
    @request.data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate']) + 1
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float(((cards) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end
   
end
