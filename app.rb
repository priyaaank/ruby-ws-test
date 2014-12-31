require 'sinatra'
require 'net/http'
require 'faye/websocket'
require 'json'
Faye::WebSocket.load_adapter('thin')

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    ws.on :open do |e|
      last_market_price = 0
      puts "websocket connection open"
      timer = EM.add_periodic_timer(1) do
        begin
          uri = URI('http://demonancy.azurewebsites.net/index/nse')
          data = Net::HTTP.get(uri)
          json_data = JSON.parse(data)
          if last_market_price != json_data["currentPrice"]
            last_market_price = json_data["currentPrice"]
            response = [{"data" => JSON.parse(data)  , "channel" => "test", "successful"=>true}].to_json
            puts "sending response : #{response}"
            ws.send(response)
          end
        rescue NoMethodError
          EM.cancel_timer(timer)
        end
      end
    end

    ws.on :close do |event|
      puts "websocket connection closed"
      ws = nil
    end

    ws.rack_response
  else
    if env["REQUEST_PATH"] == "/"
      [200, {}, File.read('./index.html')]
    else
      [404, {}, '']
    end
  end
end
