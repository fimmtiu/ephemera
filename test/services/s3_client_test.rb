require "test_helper"
require "aws-sdk-s3"

class S3ClientTest < ActiveSupport::TestCase
  setup do
    @s3_stub = Aws::S3::Client.new(stub_responses: true)
    @credentials = {
      access_key_id: "test-key",
      secret_access_key: "test-secret",
      endpoint: "http://localhost:9000",
      region: "us-east-1",
      bucket: "test-bucket"
    }

    Rails.application.credentials.stubs(:s3).returns(@credentials)
    Aws::S3::Client.stubs(:new).returns(@s3_stub)
    @client = S3Client.new
  end

  test "upload sends file to S3" do
    file = Tempfile.new(["test", ".jpg"])
    file.write("fake image data")
    file.rewind

    @s3_stub.stub_responses(:put_object, {})
    assert_nothing_raised { @client.upload("photos/test.jpg", file.path, content_type: "image/jpeg") }
  ensure
    file.close
    file.unlink
  end

  test "download retrieves file from S3" do
    @s3_stub.stub_responses(:get_object, { body: "fake image data" })

    dest = Tempfile.new(["download", ".jpg"])
    @client.download("photos/test.jpg", dest.path)
    assert_equal "fake image data", File.read(dest.path)
  ensure
    dest.close
    dest.unlink
  end

  test "delete removes object from S3" do
    @s3_stub.stub_responses(:delete_object, {})
    assert_nothing_raised { @client.delete("photos/test.jpg") }
  end
end
