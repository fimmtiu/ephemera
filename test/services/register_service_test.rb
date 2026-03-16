require "test_helper"
require "webmock/minitest"

class RegisterServiceTest < ActiveSupport::TestCase
  setup do
    @config_dir = Dir.mktmpdir
    @config_path = File.join(@config_dir, "mastodon.json")

    initial_config = {
      "server" => "https://mastodon.test",
      "app_name" => "Ephemera",
      "client_id" => nil,
      "client_secret" => nil,
      "access_token" => nil,
      "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
    }
    File.write(@config_path, JSON.pretty_generate(initial_config))
  end

  teardown do
    FileUtils.rm_rf(@config_dir)
  end

  test "full registration flow" do
    # Stub app creation
    stub_request(:post, "https://mastodon.test/api/v1/apps")
      .to_return(
        status: 200,
        body: { client_id: "new_id", client_secret: "new_secret" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub token exchange
    stub_request(:post, "https://mastodon.test/oauth/token")
      .to_return(
        status: 200,
        body: { access_token: "new_token", token_type: "Bearer" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub verify credentials
    stub_request(:get, "https://mastodon.test/api/v1/accounts/verify_credentials")
      .to_return(
        status: 200,
        body: { id: "123", username: "testuser" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    input = StringIO.new("auth_code_123\n")
    output = StringIO.new

    service = RegisterService.new(config_path: @config_path)
    service.run(input: input, output: output)

    # Verify config was updated
    saved_config = JSON.parse(File.read(@config_path))
    assert_equal "new_id", saved_config["client_id"]
    assert_equal "new_secret", saved_config["client_secret"]
    assert_equal "new_token", saved_config["access_token"]

    # Verify output
    output_text = output.string
    assert_includes output_text, "Registering app"
    assert_includes output_text, "App registered"
    assert_includes output_text, "Logged in as @testuser"
  end
end
