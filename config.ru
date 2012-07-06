require './start'
use Rack::ShowExceptions #add so even in production, my internal users can give me some feedback
run Churnobyl
