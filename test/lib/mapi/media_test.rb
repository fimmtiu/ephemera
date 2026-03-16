require "test_helper"
require "webmock/minitest"
require "mapi"

class Mapi::MediaTest < ActiveSupport::TestCase
  setup do
    @config = {
      "server" => "https://mastodon.test",
      "app_name" => "Ephemera",
      "client_id" => "abc123",
      "client_secret" => "secret456",
      "access_token" => "test_token",
      "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
    }
    @client = Mapi::Client.new(config: @config)
  end

  test "create uploads media attachment" do
    stub_request(:post, "https://mastodon.test/api/v2/media")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: { id: "media_123", type: "image", url: "https://mastodon.test/media/image.jpg" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    file = Tempfile.new(["test", ".jpg"])
    file.write("fake image data")
    file.rewind

    result = Mapi::Media.create(@client, file.path, description: "A beautiful sunset")
    assert_equal "media_123", result["id"]
    assert_equal "image", result["type"]
  ensure
    file.close
    file.unlink
  end

  test "create sends file and description as multipart form" do
    request_made = false
    stub_request(:post, "https://mastodon.test/api/v2/media")
      .with(headers: { "Authorization" => "Bearer test_token" }) { |req| request_made = true }
      .to_return(
        status: 200,
        body: { id: "media_123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    file = Tempfile.new(["test", ".jpg"])
    file.write("fake image data")
    file.rewind

    Mapi::Media.create(@client, file.path, description: "Test image")
    assert request_made, "Expected POST to /api/v2/media"
  ensure
    file.close
    file.unlink
  end
end
