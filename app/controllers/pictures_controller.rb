class PicturesController < ApplicationController
  before_action :set_picture, only: [:show, :edit, :update, :destroy, :replace, :delete_and_next]

  def index
    @pictures = Picture.order(:order)
  end

  def show
    @image_url = S3Client.new.presigned_url(@picture.s3_key)
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
    s3 = S3Client.new
    @image_url = s3.presigned_url(@picture.s3_key)
    filename = @picture.original_filename || File.basename(@picture.s3_key)
    @download_url = s3.presigned_url(@picture.s3_key,
      response_content_disposition: "attachment; filename=\"#{filename}\"")
  end

  def update
    new_order = params[:picture][:order]&.to_i

    if new_order && new_order != @picture.order
      @picture.reorder_to(new_order)
    end

    if @picture.update(picture_params)
      if params[:commit] == "Save and next"
        next_picture = Picture.where('"order" > ?', @picture.order).order(:order).first
        redirect_to next_picture ? edit_picture_path(next_picture) : pictures_path, notice: "Picture updated."
      else
        redirect_to pictures_path, notice: "Picture updated."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def replace
    file = params[:picture][:file]

    if file.blank?
      redirect_to edit_picture_path(@picture), alert: "Please select a file."
      return
    end

    tempfile = file.tempfile.path
    ExifSanitizer.new(tempfile).sanitize!

    old_key = @picture.s3_key
    new_key = "pictures/#{SecureRandom.uuid}/#{file.original_filename}"
    s3 = S3Client.new
    s3.upload(new_key, tempfile, content_type: file.content_type)
    @picture.update!(s3_key: new_key, original_filename: file.original_filename, content_type: file.content_type)
    s3.delete(old_key)

    redirect_to edit_picture_path(@picture), notice: "Image replaced."
  end

  def delete_and_next
    next_picture = Picture.where('"order" > ?', @picture.order).order(:order).first
    S3Client.new.delete(@picture.s3_key)
    @picture.destroy!
    redirect_to next_picture ? edit_picture_path(next_picture) : pictures_path, notice: "Picture deleted."
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
