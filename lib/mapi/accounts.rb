module Mapi
  module Accounts
    def self.verify_credentials(client)
      client.get("/api/v1/accounts/verify_credentials")
    end

    def self.update_credentials(client, **params)
      client.patch("/api/v1/accounts/update_credentials", body: params)
    end

    def self.followers(client, account_id, limit: 40)
      client.get("/api/v1/accounts/#{account_id}/followers", params: { limit: limit })
    end
  end
end
