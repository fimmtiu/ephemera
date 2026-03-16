require "test_helper"

class LogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "index displays posting logs" do
    picture = Picture.create!(s3_key: "photos/test.jpg", original_filename: "test.jpg")
    Log.create!(picture: picture, posted_at: Time.current, posted_order: 1)

    get logs_url
    assert_response :success
  end

  test "index requires authentication" do
    delete session_url
    get logs_url
    assert_response :redirect
  end
end
