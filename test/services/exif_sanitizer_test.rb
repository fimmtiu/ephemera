require "test_helper"

class ExifSanitizerTest < ActiveSupport::TestCase
  test "sanitize calls exiftool with correct arguments" do
    file_path = "/tmp/test_image.jpg"
    FileUtils.touch(file_path)

    expected_tags = ExifSanitizer::ALLOWED_TAGS.map { |t| "-#{t}" }

    # We verify the command is constructed correctly
    sanitizer = ExifSanitizer.new(file_path)

    command = sanitizer.send(:build_command)
    assert_includes command, "-all="
    assert_includes command, "-tagsfromfile"
    assert_includes command, "@"
    assert_includes command, "-overwrite_original"
    expected_tags.each do |tag|
      assert_includes command, tag
    end
    assert_includes command, file_path
  ensure
    FileUtils.rm_f(file_path)
  end

  test "sanitize! executes the command" do
    file_path = "/tmp/test_sanitize.jpg"
    FileUtils.touch(file_path)

    sanitizer = ExifSanitizer.new(file_path)
    sanitizer.stubs(:system).returns(true)

    assert_nothing_raised { sanitizer.sanitize! }
  ensure
    FileUtils.rm_f(file_path)
  end

  test "sanitize! raises on failure" do
    file_path = "/tmp/test_fail.jpg"
    FileUtils.touch(file_path)

    sanitizer = ExifSanitizer.new(file_path)
    sanitizer.stubs(:system).returns(false)

    assert_raises(ExifSanitizer::SanitizationError) { sanitizer.sanitize! }
  ensure
    FileUtils.rm_f(file_path)
  end

  test "ALLOWED_TAGS contains expected technical tags" do
    assert_includes ExifSanitizer::ALLOWED_TAGS, "FNumber"
    assert_includes ExifSanitizer::ALLOWED_TAGS, "ExposureTime"
    assert_includes ExifSanitizer::ALLOWED_TAGS, "ISOSpeedRatings"
    assert_includes ExifSanitizer::ALLOWED_TAGS, "ImageWidth"
    assert_includes ExifSanitizer::ALLOWED_TAGS, "Orientation"
  end

  test "ALLOWED_TAGS does not contain forbidden tags" do
    forbidden = %w[GPSLatitude GPSLongitude DateTime Make Model SerialNumber Artist Copyright Software]
    forbidden.each do |tag|
      assert_not_includes ExifSanitizer::ALLOWED_TAGS, tag
    end
  end
end
