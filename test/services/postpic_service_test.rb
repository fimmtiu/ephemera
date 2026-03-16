require "test_helper"
require "webmock/minitest"

class PostpicServiceTest < ActiveSupport::TestCase
  setup do
    Log.delete_all
    Picture.delete_all

    @p1 = Picture.create!(s3_key: "photos/a.jpg", alt_text: "Sunset", hashtags: "#sunset #photo", original_filename: "sunset.jpg")
    @p2 = Picture.create!(s3_key: "photos/b.jpg", alt_text: "Mountain", hashtags: "#mountain", original_filename: "mountain.jpg")
    @p3 = Picture.create!(s3_key: "photos/c.jpg", alt_text: "Ocean", hashtags: "#ocean", sensitive_content: "Nudity", original_filename: "ocean.jpg")
  end

  test "posts first picture when no logs exist" do
    mock_s3 = mock("s3_client")
    mock_s3.expects(:download).once
    S3Client.stubs(:new).returns(mock_s3)

    Mapi::Media.stubs(:create).returns({ "id" => "media_1" })
    Mapi::Statuses.stubs(:create).returns({ "id" => "status_1" })

    output = StringIO.new
    PostpicService.new(output: output).run

    assert_equal 1, Log.count
    log = Log.last
    assert_equal @p1, log.picture
    assert_equal 1, log.posted_order
    assert_includes output.string, "Posted successfully"
  end

  test "posts next picture in sequence" do
    Log.create!(picture: @p1, posted_at: 1.day.ago, posted_order: 1)

    mock_s3 = mock("s3_client")
    mock_s3.expects(:download).once
    S3Client.stubs(:new).returns(mock_s3)

    Mapi::Media.stubs(:create).returns({ "id" => "media_2" })
    Mapi::Statuses.stubs(:create).returns({ "id" => "status_2" })

    output = StringIO.new
    PostpicService.new(output: output).run

    assert_equal 2, Log.count
    log = Log.last
    assert_equal @p2, log.picture
    assert_equal 2, log.posted_order
  end

  test "wraps around when reaching end" do
    Log.create!(picture: @p3, posted_at: Time.current, posted_order: 3)

    mock_s3 = mock("s3_client")
    mock_s3.expects(:download).once
    S3Client.stubs(:new).returns(mock_s3)

    Mapi::Media.stubs(:create).returns({ "id" => "media_1" })
    Mapi::Statuses.stubs(:create).returns({ "id" => "status_1" })

    output = StringIO.new
    PostpicService.new(output: output).run

    log = Log.order(posted_at: :desc).first
    assert_equal @p1, log.picture
    assert_equal 1, log.posted_order
  end

  test "sets sensitive flag for sensitive content" do
    Log.create!(picture: @p1, posted_at: 2.days.ago, posted_order: 1)
    Log.create!(picture: @p2, posted_at: 1.day.ago, posted_order: 2)

    mock_s3 = mock("s3_client")
    mock_s3.expects(:download).once
    S3Client.stubs(:new).returns(mock_s3)

    Mapi::Media.stubs(:create).returns({ "id" => "media_3" })
    Mapi::Statuses.expects(:create).with(
      anything,
      media_ids: ["media_3"],
      status: "#ocean",
      sensitive: true,
      spoiler_text: "Nudity"
    ).returns({ "id" => "status_3" })

    output = StringIO.new
    PostpicService.new(output: output).run
  end

  test "handles no pictures" do
    Picture.delete_all
    output = StringIO.new
    PostpicService.new(output: output).run
    assert_includes output.string, "No pictures to post"
    assert_equal 0, Log.count
  end
end
