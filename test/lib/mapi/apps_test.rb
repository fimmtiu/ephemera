require "test_helper"
require "webmock/minitest"
require "mapi"

class Mapi::AppsTest < ActiveSupport::TestCase
  setup do
    @config = {
      "server" => "https://mastodon.test",
      "app_name" => "Ephemera",
      "client_id" => nil,
      "client_secret" => nil,
      "access_token" => nil,
      "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
    }
    @client = Mapi::Client.new(config: @config)
  end

  test "create registers a new application" do
    stub_request(:post, "https://mastodon.test/api/v1/apps")
      .with(body: hash_including(
        "client_name" => "Ephemera",
        "redirect_uris" => "urn:ietf:wg:oauth:2.0:oob",
        "scopes" => "read:accounts read:follows write:media write:statuses write:accounts"
      ))
      .to_return(
        status: 200,
        body: {
          id: "123",
          client_id: "abc123",
          client_secret: "secret456",
          name: "Ephemera",
          redirect_uri: "urn:ietf:wg:oauth:2.0:oob"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::Apps.create(@client)
    assert_equal "abc123", result["client_id"]
    assert_equal "secret456", result["client_secret"]
  end
end
