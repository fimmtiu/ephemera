require "test_helper"
require "webmock/minitest"

class FollowersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }

    @account = { "id" => "123", "username" => "testuser" }
    @followers = [
      { "id" => "456", "username" => "follower1", "display_name" => "Follower One", "avatar" => "https://mastodon.test/av1.jpg" },
      { "id" => "789", "username" => "follower2", "display_name" => "Follower Two", "avatar" => "https://mastodon.test/av2.jpg" }
    ]
  end

  test "index displays followers" do
    Mapi::Accounts.stubs(:verify_credentials).returns(@account)
    Mapi::Accounts.stubs(:followers).returns(@followers)
    get followers_url
    assert_response :success
  end

  test "index requires authentication" do
    delete session_url
    get followers_url
    assert_response :redirect
  end
end
