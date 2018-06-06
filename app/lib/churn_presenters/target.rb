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

    if @request.interval == 'month'
      @period = 365.25/12.0 # average month inc leap years
      @period_desc = 'month'
    else
      @period = 7
      @period_desc = 'week'
    end

    @start_date = Date.parse(@request.params['startDate'])
    @end_date = Date.parse(@request.params['endDate'])
    @days_duration = (@end_date + 1) - @start_date

    @paying_start_total = paying_start_total
    @paying_end_total = paying_end_total
    @paying_transfers_total = paying_transfers_total

    # the number of people who stopped paying
    @stopped = 0
    @request.data.each { | row | @stopped -= row['paying_real_loss'].to_i }

    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    @resume = 0
    @request.data.each { | row | @resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) }

    @paying_real_gain = 0
    @request.data.each { | row | @paying_real_gain += row['paying_real_gain'].to_i }

    @a1p_to_paying = 0
    @request.data.each { | row | @a1p_to_paying += row['a1p_to_paying'].to_i }

    @paying_net = 0
    @request.data.each { | row | @paying_net += row['paying_real_net'].to_i }

    #cards_in
    @cards_in = 0
    @request.data.each { | row | @cards_in += row['a1p_real_gain'].to_i }

    @cards_per_period = Float(((@cards_in) / Float(@days_duration) * @period )).round(1)

    # count the joiners who fail to convert to paying
    @failed = 0
    @request.data.each { | row | @failed -= row['a1p_to_other'].to_i }
    @conversion_rate = -Float(@a1p_to_paying) / Float(@cards_in)
    @conversion_rate = 1 if @conversion_rate.nan?

    #http://en.wikipedia.org/wiki/Turnover_(employment)
    @real_losses = @stopped - @resume
    @turn_over = 0
    @turn_over = (Float(@real_losses)) / (Float(@paying_start_total + @paying_end_total) / 2.0) if ((@paying_start_total + @paying_end_total) != 0)
    @annual_turn_over = (Float(@real_losses) / Float(@days_duration) * 365.25) / (Float(@paying_start_total + @paying_end_total) / 2.0)

    #turn over would be different at 10% growth
    @growth = Float(@paying_start_total) * growth_target / 365.25 * Float(@days_duration) # very crude growth calculation - But I don't think CAGR makes sense, the formula would be # growth = (((10% + 1) ^ (duration/365.25) * start) - start)
    @real_losses_with_growth = @turn_over * (( Float(@paying_start_total + @paying_start_total + @growth)) / 2.0)

    #cards_hold
    @cards_hold = @real_losses / @conversion_rate
    @cards_hold_per_period = Float(@cards_hold) / Float(@days_duration) * @period

    if @cards_hold.to_s == 'infinity'
      @cards_hold_display = 'infinity'
    else
      @cards_hold_display = @cards_hold.round(1)
    end


    #cards_grow
    @cards_grow = (@real_losses_with_growth + @growth) / @conversion_rate
    @cards_grow_per_period = Float(@cards_grow) / Float(@days_duration) * @period

    if @cards_grow.to_s == 'infinity'
      @cards_grow_display = 'infinity'
    else
      @cards_grow_display = @cards_grow.round(1)
    end
  end

  def periods
    (Float(@days_duration) / @period).round(1)
  end

  def period_desc
    @period_desc
  end

  def growth_target
    0.06 #GrowthTarget # see lib/settings.rb
  end

  def growth
    end_count = (@paying_start_total - @stopped + @paying_real_gain).to_f
    years = @days_duration.to_f / 365.25
    g =
      begin
         Float((((end_count / @paying_start_total) ** (1/years)) - 1) * 100).round(1)
      rescue StandardError => err
        "NaN".to_f
      end

    g = 0 if g.to_s == "NaN"
    g
  end

  def get_paying_net
    @paying_net
  end

  def get_real_losses
    @real_losses
  end

  def get_cards_in_growth_target
    @cards_grow_per_period.round(1)
  end

  def get_cards_in_target
    @cards_hold_per_period.round(1)
  end

  def get_cards_in
    @cards_per_period
  end

  def getmath_get_cards_in_target
    #"#{cards.round(0)} cards needed (#{stopped} #{col_names['paying_real_loss']} + #{failed} #{col_names['a1p_to_other']} - #{resume} resumed paying without a card (#{paying_real_gain} #{col_names['paying_real_gain']} - #{-a1p_to_paying} #{col_names['a1p_to_paying']}) ) / #{periods.round(1)} periods = #{cards_per_period}  cards per period.  We add #{growth_per_period} cards per period for 10% growth (10% = #{growth} )"
    <<~HTML
      <pre>
        CARDS_NEEDED_TO_HOLD_OUR_GROUND_PER_#{@period_desc.upcase} (#{@cards_hold_per_period.round(1)}) = cards_needed_to_hold_our_ground (#{@cards_hold_display}) / days_duration (#{@days_duration.round(0)}) * #{@period}
        cards_needed_to_hold_our_ground (#{@cards_hold_display}) = losses (#{@real_losses.round(0)}) / rough_conversion_rate (#{(@conversion_rate * 100).round(1)}%)
        rough_conversion_rate (#{(@conversion_rate * 100).round(1)}%) = cards_in_that_start_paying (#{-@a1p_to_paying.round(0)}) / cards_in (#{@cards_in})
        losses (#{@real_losses.round(0)}) = people_who_stop_paying (#{@stopped.round(0)}) - people_who_resume_paying (#{@resume.round(0)})
        days_duration (#{@days_duration.round(0)}) = @end_date (#{@end_date}) + 1 - @start_date (#{@start_date})

        CARDS_NEEDED_TO_GROW_PER_#{@period_desc.upcase} (#{@cards_grow_per_period.round(1)}) = cards_need_to_grow (#{@cards_grow_display}) / days_duration (#{@days_duration.round(0)}) * #{@period}
        cards_needed_to_grow (#{@cards_grow_display}) = (losses_from_larger_patch (#{@real_losses_with_growth.round(0)}) + desired_growth_for_period (#{@growth.round(0)})) / rough_conversion_rate (#{(@conversion_rate * 100).round(1)}%)
        losses_from_larger_patch (#{@real_losses_with_growth.round(0) }) = turn_over (#{(@turn_over * 100).round(1)}%) * (( start_count (#{@paying_start_total.round(0)}) + start_count (#{@paying_start_total.round(0)}) + desired_growth_for_period (#{@growth.round(0)}) ) / 2)
        desired_growth_for_period (#{@growth.round(0)}) = start_count (#{@paying_start_total.round(0)}) * #{growth_target*100}% / 365.25 * days_duration (#{@days_duration.round(0)})
        turn_over (#{(@turn_over * 100).round(1)}%) = losses (#{@real_losses.round(0)}) / ((start_count (#{@paying_start_total.round(0)}) + end_count (#{@paying_end_total.round(0)})) / 2 ) - http://en.wikipedia.org/wiki/Turnover_(employment)

        annual_turn_over = #{(@annual_turn_over * 100).round(1)}%
      </pre>
    HTML
  end
end
