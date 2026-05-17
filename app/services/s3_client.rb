class S3Client
  def initialize
    creds = Rails.application.credentials.s3
    @client = Aws::S3::Client.new(
      access_key_id: creds[:access_key_id],
      secret_access_key: creds[:secret_access_key],
      endpoint: creds[:endpoint],
      region: creds[:region],
      force_path_style: true
    )
    @bucket = creds[:bucket]
  end

  def upload(key, file_path, content_type:)
    File.open(file_path, "rb") do |file|
      @client.put_object(bucket: @bucket, key: key, body: file, content_type: content_type)
    end
  end

  def download(key, dest_path)
    @client.get_object(bucket: @bucket, key: key, response_target: dest_path)
  end

  def delete(key)
    @client.delete_object(bucket: @bucket, key: key)
  end

  def presigned_url(key, expires_in: 3600, response_content_disposition: nil)
    signer = Aws::S3::Presigner.new(client: @client)
    options = { bucket: @bucket, key: key, expires_in: expires_in }
    options[:response_content_disposition] = response_content_disposition if response_content_disposition
    signer.presigned_url(:get_object, **options)
  end
end
