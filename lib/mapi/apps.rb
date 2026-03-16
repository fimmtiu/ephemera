module Mapi
  module Apps
    SCOPES = "read:accounts read:follows write:media write:statuses write:accounts"

    def self.create(client)
      client.post("/api/v1/apps", body: {
        client_name: client.config["app_name"],
        redirect_uris: client.config["redirect_uri"],
        scopes: SCOPES
      })
    end
  end
end
