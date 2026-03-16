class PostpicService
  def initialize(output: $stdout)
    @output = output
  end

  def run
    next_order = Log.next_scheduled_order
    picture = Picture.find_by(order: next_order)

    unless picture
      @output.puts "No pictures to post."
      return
    end

    @output.puts "Posting picture ##{picture.order}: #{picture.original_filename || picture.s3_key}"

    tempfile = Tempfile.new(["postpic", File.extname(picture.original_filename || ".jpg")])
    begin
      S3Client.new.download(picture.s3_key, tempfile.path)

      client = Mapi::Client.new
      media = Mapi::Media.create(client, tempfile.path, description: picture.alt_text || "")

      status_params = {
        media_ids: [media["id"]],
        status: picture.hashtags || "",
        sensitive: picture.sensitive_content.present?,
        spoiler_text: picture.sensitive_content.presence
      }
      Mapi::Statuses.create(client, **status_params)

      Log.create!(
        picture: picture,
        posted_at: Time.current,
        posted_order: picture.order
      )

      @output.puts "Posted successfully!"
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
