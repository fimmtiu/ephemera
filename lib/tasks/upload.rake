require "net/http"
require "uri"
require "securerandom"

desc "Upload an image to a running Ephemera instance. " \
     "Reads credentials from EPHEMERA_EMAIL, EPHEMERA_PASSWORD, and EPHEMERA_HOST."
task :upload, [:filename] do |_, args|
  filename = args[:filename]&.strip
  hostname = ENV["EPHEMERA_HOST"]
  email    = ENV["EPHEMERA_EMAIL"]
  password = ENV["EPHEMERA_PASSWORD"]

  abort "Usage: rake 'upload[/path/to/image.jpg]'"   if filename.nil?
  abort "Set EPHEMERA_HOST environment variable"     unless hostname
  abort "Set EPHEMERA_EMAIL environment variable"    unless email
  abort "Set EPHEMERA_PASSWORD environment variable" unless password
  abort "File not found: #{filename}"                unless File.exist?(filename)

  client = EphemeraUploadClient.new(hostname)
  client.login(email, password)
  client.upload(filename)
  puts "Uploaded #{File.basename(filename)}."
ensure
  client&.close
end

class EphemeraUploadClient
  MIME_TYPES = {
    ".jpg"  => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png"  => "image/png",
    ".gif"  => "image/gif",
    ".webp" => "image/webp",
    ".heic" => "image/heic",
    ".tiff" => "image/tiff",
    ".tif"  => "image/tiff"
  }.freeze

  def initialize(hostname)
    base = hostname.match?(/\Ahttps?:\/\//) ? hostname : "https://#{hostname}"
    uri  = URI(base)
    @http = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https")
    @cookies = {}
    @csrf_token = nil
  end

  def login(email, password)
    resp = get("/session/new")
    abort "Could not reach login page (#{resp.code})" unless resp.code == "200"
    abort "Could not find CSRF token on login page — is EPHEMERA_HOST correct?" unless @csrf_token

    resp = post_form("/session",
      "authenticity_token" => @csrf_token,
      "email_address"      => email,
      "password"           => password
    )

    if resp.code == "422"
      abort "CSRF token rejected (422) — the login page may have changed"
    end

    location = resp["location"].to_s
    if location.end_with?("/session/new") || location.end_with?("/session")
      abort "Login failed — check EPHEMERA_EMAIL and EPHEMERA_PASSWORD"
    end
    abort "Login failed (#{resp.code})" unless resp.code.start_with?("3")

    puts "Logged in."
  end

  def upload(filename)
    resp = get("/pictures/new")
    abort "Could not reach upload page (#{resp.code})" unless resp.code == "200"

    boundary = "boundary#{SecureRandom.hex(16)}"
    body     = build_multipart(boundary, filename)

    resp = post_multipart("/pictures", body, boundary)
    abort "Upload failed (#{resp.code})" unless resp.code.start_with?("2") || resp.code.start_with?("3")
  end

  def close
    @http.finish if @http.started?
  end

  private

  def get(path)
    resp = @http.get(path, "Cookie" => cookie_header)
    update_state(resp)
    resp
  end

  def post_form(path, params)
    resp = @http.post(path,
      URI.encode_www_form(params),
      "Content-Type" => "application/x-www-form-urlencoded",
      "Cookie"       => cookie_header
    )
    update_state(resp)
    resp
  end

  def post_multipart(path, body, boundary)
    resp = @http.post(path, body,
      "Content-Type"   => "multipart/form-data; boundary=#{boundary}",
      "Content-Length" => body.bytesize.to_s,
      "Cookie"         => cookie_header
    )
    update_state(resp)
    resp
  end

  def update_state(resp)
    resp.get_fields("set-cookie")&.each do |cookie|
      name, value = cookie.split(";").first.split("=", 2)
      @cookies[name] = value
    end
    if (token = resp.body.to_s[/<meta name="csrf-token" content="([^"]+)"/, 1])
      @csrf_token = token
    end
  end

  def cookie_header
    @cookies.map { |k, v| "#{k}=#{v}" }.join("; ")
  end

  def build_multipart(boundary, filename)
    basename     = File.basename(filename)
    content_type = MIME_TYPES.fetch(File.extname(filename).downcase, "application/octet-stream")
    file_data    = File.binread(filename)

    body = "".b
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"authenticity_token\"\r\n\r\n"
    body << "#{@csrf_token}\r\n"
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"pictures[files][]\"; filename=\"#{basename}\"\r\n"
    body << "Content-Type: #{content_type}\r\n\r\n"
    body << file_data
    body << "\r\n--#{boundary}--\r\n"
    body
  end
end
