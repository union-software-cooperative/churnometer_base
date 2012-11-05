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

require File.expand_path(File.dirname(__FILE__) + "/../../start")
require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require 'capybara'
require 'capybara/dsl'

Capybara.app = Churnobyl
Capybara.default_driver = :selenium
Capybara.server_boot_timeout = 50
Capybara.save_and_open_page_path = './tmp/capybara/'

include Capybara::DSL

$regression_config_str = File.read(File.join(File.dirname(__FILE__), '/../config/config_regression.yaml'))
