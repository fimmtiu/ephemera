require "test_helper"
require "webmock/minitest"
require "mapi"

class Mapi::ClientTest < ActiveSupport::TestCase
  setup do
    @config = {
      "server" => "https://mastodon.test",
      "app_name" => "TestApp",
      "client_id" => "test_client_id",
      "client_secret" => "test_client_secret",
      "access_token" => "test_token",
      "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
    }
    @client = Mapi::Client.new(config: @config)
  end

  test "get sends authenticated GET request and parses JSON" do
    stub_request(:get, "https://mastodon.test/api/v1/accounts/verify_credentials")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(status: 200, body: '{"id":"123","username":"testuser"}', headers: { "Content-Type" => "application/json" })

    result = @client.get("/api/v1/accounts/verify_credentials")
    assert_equal "123", result["id"]
    assert_equal "testuser", result["username"]
  end

  test "post sends authenticated POST request with JSON body" do
    stub_request(:post, "https://mastodon.test/api/v1/statuses")
      .with(
        headers: { "Authorization" => "Bearer test_token", "Content-Type" => "application/json" },
        body: { status: "Hello world" }.to_json
      )
      .to_return(status: 200, body: '{"id":"456"}', headers: { "Content-Type" => "application/json" })

    result = @client.post("/api/v1/statuses", body: { status: "Hello world" })
    assert_equal "456", result["id"]
  end

  test "patch sends authenticated PATCH request" do
    stub_request(:patch, "https://mastodon.test/api/v1/accounts/update_credentials")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(status: 200, body: '{"id":"123"}', headers: { "Content-Type" => "application/json" })

    result = @client.patch("/api/v1/accounts/update_credentials", body: { display_name: "New Name" })
    assert_equal "123", result["id"]
  end

  test "post_form sends multipart form data" do
    stub_request(:post, "https://mastodon.test/api/v2/media")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(status: 200, body: '{"id":"789","type":"image"}', headers: { "Content-Type" => "application/json" })

    result = @client.post_form("/api/v2/media", { description: "test" })
    assert_equal "789", result["id"]
  end

  test "raises error on 4xx response" do
    stub_request(:get, "https://mastodon.test/api/v1/test")
      .to_return(status: 401, body: '{"error":"Unauthorized"}', headers: { "Content-Type" => "application/json" })

    error = assert_raises(Mapi::ApiError) { @client.get("/api/v1/test") }
    assert_equal 401, error.status
    assert_includes error.message, "Unauthorized"
  end

  test "raises error on 5xx response" do
    stub_request(:get, "https://mastodon.test/api/v1/test")
      .to_return(status: 500, body: '{"error":"Internal Server Error"}', headers: { "Content-Type" => "application/json" })

    error = assert_raises(Mapi::ApiError) { @client.get("/api/v1/test") }
    assert_equal 500, error.status
  end

  test "get without authentication (no access_token)" do
    config = @config.merge("access_token" => nil)
    client = Mapi::Client.new(config: config)

    stub_request(:get, "https://mastodon.test/api/v1/test")
      .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

    result = client.get("/api/v1/test")
    assert_equal true, result["ok"]
  end

  test "loads config from file when no config hash provided" do
    config_path = Rails.root.join("config", "mastodon.json")
    File.write(config_path, @config.to_json)

    client = Mapi::Client.new
    assert_equal "https://mastodon.test", client.config["server"]
  ensure
    # Restore original
    original = {
      "server" => "https://mastodon.example.com",
      "app_name" => "Ephemera",
      "client_id" => nil,
      "client_secret" => nil,
      "access_token" => nil,
      "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
    }
    File.write(config_path, JSON.pretty_generate(original))
  end
end
