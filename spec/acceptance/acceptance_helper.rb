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
