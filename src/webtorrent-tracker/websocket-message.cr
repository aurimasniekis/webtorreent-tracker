module Webtorrent::Tracker
  class WebsocketMessage
    def initialize(@client_id : String, @json_request : String)
      @webtorrent_message = WebtorrentMessage.from_json(@json_request)
    end
  end
end
