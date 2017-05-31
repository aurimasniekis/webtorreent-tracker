require "json"

module Webtorrent::Tracker
  class WebTorrentException < Exception
  	def initialize(@reason : String? = nil, @cause : Exception? = nil, @close_connection : Bool = false)
  		@message = "WebtorrentExcetpion: #{@reason}"
  	end

  	def to_json
  		JSON.build do |json|
  			json.object do
  				json.field "failure reason", (@reason.nil? ? "Error" : @reason)
  			end
  		end
  	end

  	def close_connection?
  		@close_connection
  	end
  end

  class InvalidUrlException < WebTorrentException
  	def initialize(@request : HTTP::Request)
  		super("Invalid url \"#{request.path}\"", nil, true)
  	end
  end

  class InvalidJsonBodyException < WebTorrentException
  	def initialize(cause : Exception? = nil)
  		super("Invalid JSON message received", cause)
  	end
  end

  class InvalidActionException < WebTorrentException
  	def initialize(action : String)
  		super("Invalid Action \"#{action}\" received")
  	end
  end

  class InvalidEventException < WebTorrentException
  	def initialize(event : String?)
  		super("Invalid Announce Event \"#{event}\" received")
  	end
  end


end
