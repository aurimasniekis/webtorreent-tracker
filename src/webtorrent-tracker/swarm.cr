require "redis"
require "json"

module Webtorrent::Tracker
  class Peer
    def initialize(@complete : Bool, @peerId : String, @ip : String, @port : Int32)
      @ttl = Time.now
    end

    JSON.mapping({
      complete: Bool,
      peerId: String,
      ip: String,
      port: Int32,
      ttl: {type: Time, converter: Time::EpochConverter}
      })
  end


  class Swarm
    def initialize(@redis : Redis)
      
    end

    def announce(context : SocketContext, params : WebtorrentMessage)
      peer = get_peer(params.info_hash.hex, params.peer_id.hex)

      puts "Event: #{params.event}"
      puts peer.inspect

      case params.event
      when "started"
        announce_started(peer, context, params)
      when "stopped"
        announce_started(peer, context, params)
      when "completed"
        announce_started(peer, context, params)
      when "update"
        announce_started(peer, context, params)
      else
        raise InvalidEventException.new(params.event)
      end

      numwant = params.numwant.nil? ? 0_i64 : params.numwant.as(Int64)

      {
        complete: complete(params),
        incomplete: incomplete(params),
        peers: get_peers(params.info_hash.hex, numwant, params.peer_id.hex)
      }
    end

    def announce_started(peer : Peer?, context : SocketContext, params : WebtorrentMessage)
      if peer
        return announce_update(peer, context, params)
      end

      if params.left == 0
        complete_incr(params)
      else
        incomplete_incr(params)
      end

      peer = Peer.new(params.left == 0, params.peer_id.hex, context.ip, context.port)

      add_peer(peer, params.info_hash.hex)
    end

    def announce_stopped(peer : Peer?, context : SocketContext, params : WebtorrentMessage)
      unless peer
        return
      end

      if params.left == 0
        complete_decr(params)
      else
        incomplete_decr(params)
      end

      remove_peer(peer, params.info_hash.hex)
    end

    def announce_completed(peer : Peer?, context : SocketContext, params : WebtorrentMessage)
      unless peer
        return announce_started(peer, context, params)
      end

      if peer.completed
        return announce_update(peer, context, params)
      end

      complete_incr(params)
      incomplete_decr(params)

      peer.complete = true

      add_peer(peer, params.info_hash.hex)
    end

    def announce_update(peer : Peer?, context : SocketContext, params : WebtorrentMessage)
      unless peer
        return announce_started(peer, context, params)
      end

      if false == peer.complete && params.left === 0
        complete_incr(params)
        incomplete_decr(params)

        peer.complete = true
      end

      remove_peer(peer, params.info_hash.hex)
      peer.ttl = Time.now

      add_peer(peer, params.info_hash.hex)
    end

    def get_peers(info_hash : String, numwant : Int64, ownPeerId : String)
      peers = get_peer_list(info_hash)

      result = [] of String
      peers.shuffle.each do |peer|
        if result == ownPeerId
          next
        end

        if result.size < numwant
          result << peer.as(String)
        else
          break
        end
      end

      result_peer = [] of Peer?
      result = result.map do |peer_id|
        result_peer << get_peer(info_hash, peer_id)
      end

      result_peer.compact
    end

    def scrape(params : WebtorrentMessage)
      {
        complete: complete(params),
        incomplete: incomplete(params)
      }
    end

    def complete(params : WebtorrentMessage) : Int32
      result = @redis.get(complete_key(params.info_hash.hex))

      result.nil? ? 0 : result.to_i
    end

    def incomplete(params : WebtorrentMessage) : Int32
      result = @redis.get(incomplete_key(params.info_hash.hex))

      result.nil? ? 0 : result.to_i
    end

    def complete_incr(params : WebtorrentMessage)
      @redis.incr(complete_key(params.info_hash.hex))
    end

    def complete_decr(params : WebtorrentMessage)
      @redis.decr(complete_key(params.info_hash.hex))
    end

    def incomplete_incr(params : WebtorrentMessage)
      @redis.incr(incomplete_key(params.info_hash.hex))
    end

    def incomplete_decr(params : WebtorrentMessage)
      @redis.decr(incomplete_key(params.info_hash.hex))
    end

    def complete_key(info_hash : String)
      "swarn:#{info_hash}:complete"
    end

    def incomplete_key(info_hash : String)
      "swarn:#{info_hash}:incomplete"
    end

    def peers_key(info_hash : String)
      "swarn:#{info_hash}:peers_list"
    end

    def add_peer_to_list(info_hash : String, peer : Peer)
      value = "#{peer.ttl.epoch}||#{peer.peerId}"

      @redis.sadd(peers_key(info_hash), value)
    end

    def remove_peer_from_list(info_hash : String, peer : Peer)
      value = "#{peer.ttl.epoch}||#{peer.peerId}"

      @redis.srem(peers_key(info_hash), value)
    end

    def get_peer_list(info_hash : String)
      members = @redis.smembers(peers_key(info_hash))

      members = members.map do |item|
        vals = item.as(String).split("||", 2)

        if vals.size == 2
          time, peer_id = vals
          
          if Time.epoch(time.to_i) < (Time.now + peer_ttl)
              peer_id
          else
            @redis.srem(peers_key(info_hash), item)
            nil
          end
        else
          @redis.srem(peers_key(info_hash), item)
          nil
        end
      end

      members.compact
    end

    def get_peer(info_hash : String, peer_id : String)
      result = @redis.get(peer_key(info_hash, peer_id))

      Peer.from_json(result) if result
    end

    def add_peer(peer : Peer, info_hash : String)
      puts "TTL: #{(peer.ttl.epoch - Time.now.epoch).inspect}"
      @redis.set(peer_key(info_hash, peer.peerId), peer.to_json)

      add_peer_to_list(info_hash, peer)
    end

    def remove_peer(peer : Peer, info_hash : String)
      @redis.del(peer_key(info_hash, peer.peerId))

      remove_peer_from_list(info_hash, peer)
    end

    def peer_key(info_hash : String, peer_id : String)
      "swarn:#{info_hash}:peers:#{peer_id}"
    end

    def peer_ttl
      Time::Span.new(1, 0, 0, 0)
    end
  end
end
