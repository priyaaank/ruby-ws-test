require './app'
$stdout.sync = true
Faye::WebSocket.load_adapter('thin')

use MarketTicker::Backend

run MarketTicker::Backend