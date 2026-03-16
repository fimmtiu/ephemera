require "test_helper"
require "webmock/minitest"
require "mapi"

class Mapi::AccountsTest < ActiveSupport::TestCase
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

  test "verify_credentials fetches authenticated account" do
    stub_request(:get, "https://mastodon.test/api/v1/accounts/verify_credentials")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: { id: "123", username: "testuser", display_name: "Test User" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::Accounts.verify_credentials(@client)
    assert_equal "123", result["id"]
    assert_equal "testuser", result["username"]
  end

  test "update_credentials patches account profile" do
    stub_request(:patch, "https://mastodon.test/api/v1/accounts/update_credentials")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: { id: "123", display_name: "New Name", note: "New bio" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::Accounts.update_credentials(@client, display_name: "New Name", note: "New bio")
    assert_equal "New Name", result["display_name"]
  end

  test "followers fetches account followers" do
    stub_request(:get, "https://mastodon.test/api/v1/accounts/123/followers?limit=40")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: [
          { id: "456", username: "follower1" },
          { id: "789", username: "follower2" }
        ].to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::Accounts.followers(@client, "123")
    assert_equal 2, result.length
    assert_equal "follower1", result[0]["username"]
  end
end
