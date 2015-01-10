require 'sinatra'
require 'net/http'
require 'faye/websocket'
require 'json'
require 'eventmachine'

module MarketTicker
  class Backend
    KEEPALIVE_TIME = 15 # in seconds
    CHANNEL        = "alerts"

    def initialize(app)
      @app     = app
      @clients = []
      Thread.new do
        EventMachine.run {
          puts "xxx"
          proc = Proc.new do
            if (@clients || []).size > 0
              puts "onece"
              begin
                response = {}
                alerts = AlertWatcher.new.check_for_alerts
                if (alerts||[]).size > 0
                  alerts.each do |alert|
                    response = [{"data" => alert, "channel" => CHANNEL, "successful" => true}].to_json
                    puts "sending response : #{response}"
                  end
                else
                  puts "only pining!"
                  response = [{"data" => {}, "channel" => "ping", "successful"=>true}].to_json
                end
                @clients.each {|ws| ws.send(response) }
              rescue Errno::ETIMEDOUT
                puts "TIMED OUT!!"
              rescue NoMethodError
                puts "Generic error!"
              end
            end
          end

          EventMachine.add_periodic_timer 5, proc
        }
      end
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME })
        ws.on :open do |event|
          p [:open, ws.object_id]
          @clients << ws
        end

        ws.on :message do |event|
          puts "Socket sending response : #{event.data}"
          ws.send(event.data)
        end

        ws.on :close do |event|
          p [:close, ws.object_id, event.code, event.reason]
          @clients.delete(ws)
          ws = nil
        end

        # Return async Rack response
        ws.rack_response

      else
        @app.call(env)
      end
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
    begin
      # alerts = JSON::parse(Net::HTTP.get(URI(@alert_list)))
      alerts = [{"symbol" => "HINDALCO.NS"}]
      alerts.collect do |stock|
        puts "checking for stock: #{stock['symbol']}"
        symbol = stock["symbol"]
        # alert_reponse = JSON::parse(Net::HTTP.get(URI(@alert_check.gsub("##SYMBOL##",symbol))))
        alert_reponse = "bah"
        if alert_reponse["status"] == "Pricing Alert Triggered"
          triggered_alerts << { "symbol" => symbol, "price" => stock["triggerPrice"] }
        end
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      puts "Some network error occured!! #{e}"
    end
    triggered_alerts
  end

end