module Mapi
  module Media
    def self.create(client, file_path, description: "")
      file = File.open(file_path, "rb")
      client.post_form("/api/v2/media", {
        file: file,
        description: description
      })
    ensure
      file&.close
    end
  end
end
