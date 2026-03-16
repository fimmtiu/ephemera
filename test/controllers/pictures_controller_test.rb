require "test_helper"

class PicturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @picture = pictures(:one)
  end

  test "index returns success when logged in" do
    sign_in_as(@user)
    get pictures_path
    assert_response :success
  end

  test "index shows pictures ordered by order" do
    sign_in_as(@user)
    get pictures_path
    assert_response :success
    assert_select "table tbody tr", count: Picture.count
    # Verify order column is ascending
    order_cells = Nokogiri::HTML(response.body).css("table tbody tr td:first-child").map(&:text).map(&:strip)
    assert_equal order_cells.sort_by(&:to_i), order_cells, "Pictures should be ordered by order"
  end

  test "index redirects to login when not authenticated" do
    get pictures_path
    assert_redirected_to new_session_path
  end

  test "show returns success when logged in with valid picture" do
    sign_in_as(@user)
    get picture_path(@picture)
    assert_response :success
  end

  test "show redirects when not authenticated" do
    get picture_path(@picture)
    assert_redirected_to new_session_path
  end

  test "new returns success when logged in" do
    sign_in_as(@user)
    get new_picture_path
    assert_response :success
  end

  test "new redirects when not authenticated" do
    get new_picture_path
    assert_redirected_to new_session_path
  end

  test "create creates picture with file upload" do
    sign_in_as(@user)
    tempfile = Tempfile.new(["test", ".jpg"])
    tempfile.write("fake image content")
    tempfile.rewind

    mock_s3 = mock("s3_client")
    mock_s3.stubs(:upload)
    S3Client.stubs(:new).returns(mock_s3)
    ExifSanitizer.any_instance.stubs(:sanitize!)

    assert_difference "Picture.count", 1 do
      post pictures_path, params: {
        pictures: {
          files: [fixture_file_upload(tempfile.path, "image/jpeg")]
        }
      }
    end

    assert_redirected_to pictures_path
    assert_match(/1 picture\(s\) uploaded\./, flash[:notice])
    picture = Picture.last
    assert picture.s3_key.start_with?("pictures/")
    assert picture.original_filename.end_with?(".jpg")
  end

  test "create redirects with alert when no files selected" do
    sign_in_as(@user)
    assert_no_difference "Picture.count" do
      post pictures_path, params: { pictures: { files: [] } }
    end
    assert_redirected_to new_picture_path
    assert_equal "Please select at least one file.", flash[:alert]
  end

  test "create calls ExifSanitizer and S3Client" do
    sign_in_as(@user)
    tempfile = Tempfile.new(["test", ".jpg"])
    tempfile.write("fake image")
    tempfile.rewind

    mock_s3 = mock("s3_client")
    mock_s3.expects(:upload).once
    S3Client.stubs(:new).returns(mock_s3)
    ExifSanitizer.any_instance.expects(:sanitize!).once

    post pictures_path, params: {
      pictures: {
        files: [fixture_file_upload(tempfile.path, "image/jpeg")]
      }
    }
  end

  test "edit returns success for existing picture" do
    sign_in_as(@user)
    get edit_picture_path(@picture)
    assert_response :success
  end

  test "edit redirects when not authenticated" do
    get edit_picture_path(@picture)
    assert_redirected_to new_session_path
  end

  test "update updates metadata fields" do
    sign_in_as(@user)
    patch picture_path(@picture), params: {
      picture: {
        alt_text: "Updated alt",
        hashtags: "#new #tags",
        sensitive_content: "nudity"
      }
    }
    assert_redirected_to pictures_path
    assert_match(/Picture updated\./, flash[:notice])
    @picture.reload
    assert_equal "Updated alt", @picture.alt_text
    assert_equal "#new #tags", @picture.hashtags
    assert_equal "nudity", @picture.sensitive_content
  end

  test "update triggers reorder when order changes" do
    sign_in_as(@user)
    other = pictures(:two)
    original_order = @picture.order
    new_order = other.order

    patch picture_path(@picture), params: {
      picture: { order: new_order }
    }

    assert_redirected_to pictures_path
    @picture.reload
    assert_equal new_order, @picture.order
  end

  test "update renders edit on validation failure" do
    sign_in_as(@user)
    @picture.stubs(:update).returns(false)
    Picture.stubs(:find).returns(@picture)

    patch picture_path(@picture), params: {
      picture: { alt_text: "x" }
    }

    assert_response :unprocessable_entity
    assert response.body.include?("Edit Picture")
  end

  test "destroy deletes picture and redirects to index" do
    sign_in_as(@user)
    Log.where(picture: @picture).destroy_all
    mock_s3 = mock("s3_client")
    mock_s3.stubs(:delete)
    S3Client.stubs(:new).returns(mock_s3)

    assert_difference "Picture.count", -1 do
      delete picture_path(@picture)
    end

    assert_redirected_to pictures_path
    assert_match(/Picture deleted\./, flash[:notice])
  end

  test "destroy calls S3Client delete" do
    sign_in_as(@user)
    Log.where(picture: @picture).destroy_all
    mock_s3 = mock("s3_client")
    mock_s3.expects(:delete).with(@picture.s3_key).once
    S3Client.stubs(:new).returns(mock_s3)

    delete picture_path(@picture)
  end

  test "destroy redirects when not authenticated" do
    assert_no_difference "Picture.count" do
      delete picture_path(@picture)
    end
    assert_redirected_to new_session_path
  end
end
