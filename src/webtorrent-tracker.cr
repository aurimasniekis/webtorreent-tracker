require "./webtorrent-tracker/*"
require "http/server"

module Webtorrent::Tracker
  SOCKETS = [] of HTTP::WebSocket

  ws_handler = HTTP::WebSocketHandler.new do |socket, context|
    puts "Socket opened"
    SOCKETS << socket

    unless match = context.request.path.match(/^\/([^\/]+)\/announce$/)
      socket.send "Invalid url"
      socket.close
    end

    client_id = match.as(Regex::MatchData)[1]

    socket.on_message do |message|
      File.write("/tmp/messge.json", message)
      puts WebsocketMessage.new(client_id, message).inspect
      # SOCKETS.each { |socket| socket.send "Echo back from server: #{message}" }
    end

    socket.on_close do
      puts "Socket closed"
    end
  end

  server = HTTP::Server.new("0.0.0.0", 3000, [ws_handler])
  server.listen
end
