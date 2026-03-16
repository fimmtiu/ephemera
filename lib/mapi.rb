require "mapi/client"
require "mapi/apps"
require "mapi/media"
require "mapi/accounts"
require "mapi/oauth"
require "mapi/statuses"

module Mapi
  class ApiError < StandardError
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body = body
      parsed = JSON.parse(body) rescue {}
      super("Mastodon API error (#{status}): #{parsed['error'] || body}")
    end
  end
end
