#\ -s puma
require './start'
use Rack::ShowExceptions #add so even in production, my internal users can give me some feedback

run Rack::Cascade.new([
  ApplicationController,
  PublicController,
  OAuthController,
  BasicAuthController
])
