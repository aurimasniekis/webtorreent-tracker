require "json"

module Webtorrent::Tracker
  class WebTorrentResponse
    def initialize(@action : String)
    end

    JSON.mapping({
      action: {type: String, nilable: false},
      peers: {type: Array(String), nilable: true},
      info_hash: {type: String, nilable: true}
      })
  end

  class WebtorrentMessage
    ACTION_CONNECT = "connect"
    ACTION_ANNOUNCE = "announce"
    ACTION_SCRAPE = "scrape"

    class HashValue
      property hex : String
      def initialize(@value : String)
        @hex = @value.encode("latin1").hexstring
      end
    end

    class Offers
      class Offer
        JSON.mapping({
          offer_type: {type: String, key: "type"},
          sdp:        String,
        }, true)
      end

      JSON.mapping({
        offer:    Offer,
        offer_id: String,
      }, true)
    end

    module HashParser
      def self.from_json(value : JSON::PullParser) : HashValue
        val = value.read_string
        if val.size != 20
          raise InvalidJsonBodyException.new()
        end

        HashValue.new(val)
      end
    end

    JSON.mapping({
      ip:         {type: String, nilable: true},
      port:       {type: Int32, nilable: true},
      numwant:    {type: Int64, nilable: true},
      uploaded:   {type: Int64, nilable: true},
      downloaded: {type: Int64, nilable: true},
      left:       {type: Int64, nilable: true},
      event:      {type: String, nilable: true},
      action:     {type: String},
      info_hash:  {type: HashValue, converter: HashParser},
      peer_id:    {type: HashValue, converter: HashParser},
      offers:     {type: Array(Offers), nilable: true},
    }, true)
  end

  class WebtorrentError
    def initialize(@execption : Exception)
    end

    def to_json
      puts "=============="
      puts @execption.message
      puts "=============="

      JSON.build do |json|
        json.object do
          json.field "failure reason", @execption.message
        end
      end
    end
  end
end
