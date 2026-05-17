class PicturesController < ApplicationController
  before_action :set_picture, only: [:show, :edit, :update, :destroy]

  def index
    @pictures = Picture.order(:order)
  end

  def show
  end

  def new
    @picture = Picture.new
  end

  def create
    files = Array(params[:pictures]&.[](:files)).reject(&:blank?)

    if files.empty?
      redirect_to new_picture_path, alert: "Please select at least one file."
      return
    end

    files.each do |file|
      tempfile = file.tempfile.path
      ExifSanitizer.new(tempfile).sanitize!

      key = "pictures/#{SecureRandom.uuid}/#{file.original_filename}"
      S3Client.new.upload(key, tempfile, content_type: file.content_type)

      Picture.create!(
        s3_key: key,
        original_filename: file.original_filename,
        content_type: file.content_type
      )
    end

    redirect_to pictures_path, notice: "#{files.size} picture(s) uploaded."
  end

  def edit
    @image_url = S3Client.new.presigned_url(@picture.s3_key)
  end

  def update
    new_order = params[:picture][:order]&.to_i

    if new_order && new_order != @picture.order
      @picture.reorder_to(new_order)
    end

    if @picture.update(picture_params)
      redirect_to pictures_path, notice: "Picture updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    S3Client.new.delete(@picture.s3_key)
    @picture.destroy!
    redirect_to pictures_path, notice: "Picture deleted."
  end

  private

  def set_picture
    @picture = Picture.find(params[:id])
  end

  def picture_params
    params.require(:picture).permit(:alt_text, :hashtags, :sensitive_content)
  end
end
