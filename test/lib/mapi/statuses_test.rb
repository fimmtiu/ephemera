require "test_helper"
require "webmock/minitest"
require "mapi"

class Mapi::StatusesTest < ActiveSupport::TestCase
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

  test "create posts a status with media" do
    stub_request(:post, "https://mastodon.test/api/v1/statuses")
      .with(
        headers: { "Authorization" => "Bearer test_token", "Content-Type" => "application/json" },
        body: hash_including(
          "media_ids" => ["media_123"],
          "status" => "#photography #landscape"
        )
      )
      .to_return(
        status: 200,
        body: { id: "status_456", content: "<p>#photography #landscape</p>" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::Statuses.create(@client,
      media_ids: ["media_123"],
      status: "#photography #landscape"
    )
    assert_equal "status_456", result["id"]
  end

  test "create with sensitive content sets sensitive and spoiler_text" do
    stub_request(:post, "https://mastodon.test/api/v1/statuses")
      .with(
        body: hash_including(
          "sensitive" => true,
          "spoiler_text" => "NSFW content"
        )
      )
      .to_return(
        status: 200,
        body: { id: "status_789", sensitive: true, spoiler_text: "NSFW content" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::Statuses.create(@client,
      media_ids: ["media_123"],
      status: "#art",
      sensitive: true,
      spoiler_text: "NSFW content"
    )
    assert_equal true, result["sensitive"]
    assert_equal "NSFW content", result["spoiler_text"]
  end

  test "create without sensitive defaults to false" do
    stub_request(:post, "https://mastodon.test/api/v1/statuses")
      .with(
        body: hash_including(
          "sensitive" => false
        )
      )
      .to_return(
        status: 200,
        body: { id: "status_101" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::Statuses.create(@client,
      media_ids: ["media_123"],
      status: "#cats"
    )
    assert_equal "status_101", result["id"]
  end
end
