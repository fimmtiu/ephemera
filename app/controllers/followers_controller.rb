class FollowersController < ApplicationController
  def index
    client = Mapi::Client.new
    account = Mapi::Accounts.verify_credentials(client)
    @followers = Mapi::Accounts.followers(client, account["id"])
  end
end
