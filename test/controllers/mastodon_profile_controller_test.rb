require "test_helper"
require "webmock/minitest"

class MastodonProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }

    @profile_data = {
      "id" => "123",
      "username" => "testuser",
      "display_name" => "Test User",
      "note" => "A test bio",
      "avatar" => "https://mastodon.test/avatar.jpg",
      "header" => "https://mastodon.test/header.jpg"
    }
  end

  test "show displays profile" do
    Mapi::Accounts.stubs(:verify_credentials).returns(@profile_data)
    get mastodon_profile_url
    assert_response :success
  end

  test "show requires authentication" do
    delete session_url
    get mastodon_profile_url
    assert_response :redirect
  end

  test "edit displays profile form" do
    Mapi::Accounts.stubs(:verify_credentials).returns(@profile_data)
    get edit_mastodon_profile_url
    assert_response :success
  end

  test "update patches profile" do
    Mapi::Accounts.stubs(:update_credentials).returns(@profile_data.merge("display_name" => "New Name"))
    patch mastodon_profile_url, params: { profile: { display_name: "New Name", note: "New bio" } }
    assert_redirected_to mastodon_profile_url
  end
end
