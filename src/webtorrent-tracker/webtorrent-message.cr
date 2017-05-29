require "json"

module Webtorrent::Tracker
  class WebtorrentMessage
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
      def self.from_json(value : JSON::PullParser) : String
        val = value.read_string
        if val.size != 20
          return ""
        end

        val.encode("latin1").hexstring
      end
    end

    JSON.mapping({
      numwant:    {type: Int64, nilable: true},
      uploaded:   {type: Int64, nilable: true},
      downloaded: {type: Int64, nilable: true},
      left:       {type: Int64, nilable: true},
      event:      {type: String, nilable: true},
      action:     {type: String, nilable: true},
      info_hash:  {type: String, converter: HashParser},
      peer_id:    {type: String, nilable: true, converter: HashParser},
      offers:     {type: Array(Offers), nilable: true},
    }, true)
  end
end
