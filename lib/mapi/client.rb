require "net/http"
require "uri"
require "json"

module Mapi
  class Client
    attr_reader :config

    def initialize(config: nil)
      @config = config || load_config
    end

    def get(path, params: {})
      uri = build_uri(path, params)
      request = Net::HTTP::Get.new(uri)
      set_auth_headers(request)
      execute(uri, request)
    end

    def post(path, body: {})
      uri = build_uri(path)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      set_auth_headers(request)
      execute(uri, request)
    end

    def patch(path, body: {})
      uri = build_uri(path)
      request = Net::HTTP::Patch.new(uri)
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      set_auth_headers(request)
      execute(uri, request)
    end

    def post_form(path, params)
      uri = build_uri(path)
      request = Net::HTTP::Post.new(uri)
      form_data = params.map { |k, v| [k.to_s, v] }
      request.set_form(form_data, "multipart/form-data")
      set_auth_headers(request)
      execute(uri, request)
    end

    private

    def load_config
      path = Rails.root.join("config", "mastodon.json")
      JSON.parse(File.read(path))
    end

    def build_uri(path, params = {})
      uri = URI.join(config["server"], path)
      uri.query = URI.encode_www_form(params) unless params.empty?
      uri
    end

    def set_auth_headers(request)
      token = config["access_token"]
      request["Authorization"] = "Bearer #{token}" if token
    end

    def execute(uri, request)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      body = response.body
      status = response.code.to_i

      raise Mapi::ApiError.new(status, body) unless (200..299).include?(status)

      JSON.parse(body)
    end
  end
end
