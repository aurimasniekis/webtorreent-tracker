require "./webtorrent-tracker/*"

module Webtorrent::Tracker
  SOCKETS = [] of HTTP::WebSocket

  swarm = Swarm.new(Redis.new)

  ws_handler = HTTP::WebSocketHandler.new do |socket, context|
    begin
      socket_context = SocketContext.new(socket, context, swarm)
    rescue ex : WebTorrentException
      puts "Error: #{ex.message}"

      socket.send ex.to_json
      socket.close if ex.close_connection?

      next
    end

    puts "Peer #{socket_context.client_id} connected"

    socket.on_message do |message|
      begin
       socket_context.on_message message
      rescue ex : WebTorrentException
        puts "Error: #{ex.message}"

        puts message

        socket.send ex.to_json
        socket.close if ex.close_connection?
      end
    end

    # client_id = match.as(Regex::MatchData)[1]

    # socket.on_message do |message|
    #   begin
    #     puts WebsocketMessage.new(client_id, message).inspect
    #   rescue ex : JSON::ParseException
    #     socket.send WebtorrentError.new(ex).to_json
    #     socket.close
    #   end 
    #   # SOCKETS.each { |socket| socket.send "Echo back from server: #{message}" }
    # end

    # socket.on_close do
    #   puts "Socket closed"
    # end
  end

  server = HTTPServer.new("0.0.0.0", 3000, [ws_handler])
  server.listen
end
