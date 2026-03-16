module Mapi
  module Statuses
    def self.create(client, media_ids:, status:, sensitive: false, spoiler_text: nil)
      body = {
        media_ids: media_ids,
        status: status,
        sensitive: sensitive
      }
      body[:spoiler_text] = spoiler_text if spoiler_text
      client.post("/api/v1/statuses", body: body)
    end
  end
end
