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

class ChurnPresenter_Notices
  include Settings
  include ChurnPresenter_Helpers

  attr_accessor :notices

  def initialize(app, request)
    start_date = Date.parse(request.params['startDate'])
    end_date = Date.parse(request.params['endDate'])

    @notices = if File.exist?(notices_filename)
      YAML.load(File.read(notices_filename)).map do |h|
        ChurnPresenter_Notice.new(h, start_date, end_date)
      end
    else
      {}
    end
  end

  def for_display
    @notices.select(&:display)
  end

  def notices_filename
    @notices_filename ||= "./config/notices.yaml"
  end
end

class ChurnPresenter_Notice
  attr_reader :display, :date, :message

  def initialize(notice, start_date, end_date)
    @date = Date.parse(notice["date"])

    @display = (@date >= start_date && @date <= end_date)
    @message = notice["message"]
  end
end
