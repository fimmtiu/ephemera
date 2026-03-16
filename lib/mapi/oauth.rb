require "uri"

module Mapi
  module OAuth
    SCOPES = "read:accounts read:follows write:media write:statuses write:accounts"

    def self.authorize_url(client)
      server = client.config["server"]
      params = URI.encode_www_form(
        client_id: client.config["client_id"],
        redirect_uri: client.config["redirect_uri"],
        response_type: "code",
        scope: SCOPES
      )
      "#{server}/oauth/authorize?#{params}"
    end

    def self.token(client, code)
      client.post("/oauth/token", body: {
        grant_type: "authorization_code",
        client_id: client.config["client_id"],
        client_secret: client.config["client_secret"],
        redirect_uri: client.config["redirect_uri"],
        code: code
      })
    end
  end
end
