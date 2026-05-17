class ExifSanitizer
  class SanitizationError < StandardError; end

  ALLOWED_TAGS = %w[
    FNumber
    ExposureTime
    ISOSpeedRatings
    FocalLength
    FocalLengthIn35mmFormat
    ImageWidth
    ImageHeight
    WhiteBalance
    MeteringMode
    ExposureProgram
    ExposureCompensation
    Flash
    LightSource
    SceneCaptureType
    ColorSpace
    BitsPerSample
    Compression
    PhotometricInterpretation
    Orientation
    XResolution
    YResolution
    ResolutionUnit
  ].freeze

  def initialize(file_path)
    @file_path = file_path
  end

  def sanitize!
    success = system(*build_command)
    raise SanitizationError, "exiftool failed to sanitize #{@file_path}" unless success
  end

  private

  def build_command
    cmd = ["exiftool", "-all=", "-tagsfromfile", "@"]
    ALLOWED_TAGS.each { |tag| cmd << "-#{tag}" }
    cmd << "-ICC_Profile:all"
    cmd << "-overwrite_original"
    cmd << @file_path
    cmd
  end
end
