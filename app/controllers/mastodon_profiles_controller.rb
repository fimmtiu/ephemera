class MastodonProfilesController < ApplicationController
  def show
    @profile = Mapi::Accounts.verify_credentials(mapi_client)
  end

  def edit
    @profile = Mapi::Accounts.verify_credentials(mapi_client)
  end

  def update
    profile_params = params.require(:profile).permit(:display_name, :note)
    Mapi::Accounts.update_credentials(mapi_client, **profile_params.to_h.symbolize_keys)
    redirect_to mastodon_profile_path, notice: "Profile updated."
  end

  private

  def mapi_client
    @mapi_client ||= Mapi::Client.new
  end
end
