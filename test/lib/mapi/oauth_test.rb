require "test_helper"
require "webmock/minitest"
require "mapi"

class Mapi::OAuthTest < ActiveSupport::TestCase
  setup do
    @config = {
      "server" => "https://mastodon.test",
      "app_name" => "Ephemera",
      "client_id" => "abc123",
      "client_secret" => "secret456",
      "access_token" => nil,
      "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
    }
    @client = Mapi::Client.new(config: @config)
  end

  test "authorize_url builds correct OAuth URL" do
    url = Mapi::OAuth.authorize_url(@client)
    uri = URI.parse(url)

    assert_equal "mastodon.test", uri.host
    assert_equal "/oauth/authorize", uri.path

    params = URI.decode_www_form(uri.query).to_h
    assert_equal "abc123", params["client_id"]
    assert_equal "urn:ietf:wg:oauth:2.0:oob", params["redirect_uri"]
    assert_equal "code", params["response_type"]
    assert_equal "read:accounts read:follows write:media write:statuses write:accounts", params["scope"]
  end

  test "token exchanges authorization code for access token" do
    stub_request(:post, "https://mastodon.test/oauth/token")
      .with(body: hash_including(
        "grant_type" => "authorization_code",
        "client_id" => "abc123",
        "client_secret" => "secret456",
        "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob",
        "code" => "auth_code_123"
      ))
      .to_return(
        status: 200,
        body: { access_token: "new_token_xyz", token_type: "Bearer", scope: "read write", created_at: 1234567890 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Mapi::OAuth.token(@client, "auth_code_123")
    assert_equal "new_token_xyz", result["access_token"]
    assert_equal "Bearer", result["token_type"]
  end
end
