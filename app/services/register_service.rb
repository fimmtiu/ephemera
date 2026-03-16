class RegisterService
  def initialize(config_path: Rails.root.join("config", "mastodon.json"))
    @config_path = config_path
  end

  def run(input: $stdin, output: $stdout)
    config = JSON.parse(File.read(@config_path))
    client = Mapi::Client.new(config: config)

    output.puts "Registering app '#{config['app_name']}' on #{config['server']}..."
    result = Mapi::Apps.create(client)

    config["client_id"] = result["client_id"]
    config["client_secret"] = result["client_secret"]
    save_config(config)
    output.puts "App registered. Client ID: #{config['client_id']}"

    client = Mapi::Client.new(config: config)

    auth_url = Mapi::OAuth.authorize_url(client)
    output.puts "\nPlease visit this URL in your browser to authorize the app:"
    output.puts auth_url
    output.print "\nPaste the authorization code here: "

    code = input.gets.chomp

    output.puts "Exchanging code for access token..."
    token_result = Mapi::OAuth.token(client, code)

    config["access_token"] = token_result["access_token"]
    save_config(config)
    output.puts "Access token saved."

    client = Mapi::Client.new(config: config)
    account = Mapi::Accounts.verify_credentials(client)
    output.puts "\nSuccess! Logged in as @#{account['username']}"
  end

  private

  def save_config(config)
    File.write(@config_path, JSON.pretty_generate(config))
  end
end
