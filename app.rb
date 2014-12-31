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
      timer = EM.add_periodic_timer(10) do
        begin
          alerts = AlertWatcher.new.check_for_alerts
          if (alerts||[]).size > 0
            alerts.each do |alert|
              response = [{"data" => alert, "channel" => "alerts", "successful"=>true}].to_json
              puts "sending response : #{response}"
              ws.send(response)
            end
          end
        rescue Errno::ETIMEDOUT
          puts "TIMED OUT!!"
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

class AlertWatcher

  def initialize(username="venkat")
    @alert_list = "http://demonancy.azurewebsites.net/alert/#{username}/priceAlert/list"
    @alert_check = "http://demonancy.azurewebsites.net/alert/#{username}/priceAlert?symbol=##SYMBOL##"
  end

  def check_for_alerts
    triggered_alerts = []
    alerts = JSON::parse(Net::HTTP.get(URI(@alert_list)))
    alerts.collect do |stock|
      puts "checking for stock: #{stock['symbol']}"
      symbol = stock["symbol"]
      alert_reponse = JSON::parse(Net::HTTP.get(URI(@alert_check.gsub("##SYMBOL##",symbol))))
      if alert_reponse["status"] == "Pricing Alert Triggered"
        triggered_alerts << { "symbol" => symbol, "price" => stock["triggerPrice"] }
      end
    end
    triggered_alerts
  end

end