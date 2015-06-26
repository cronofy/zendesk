class SessionsController < ApplicationController
  include ZendeskApiClient

  force_ssl if: :ssl_configured?

  def create
    log.debug { "#create #{auth_hash.inspect}" }

    case auth_hash['provider']
    when 'cronofy'
      process_cronofy_login(auth_hash)
      flash[:success] = "Connected to your calendars"
    when 'zendesk'
      process_zendesk_login(auth_hash)
      flash[:success] = "Connected to Zendesk"
    else
      log.warn { "#create provider=#{auth_hash['provider']} not recognised" }
      flash[:error] = "Unrecognised provider login"
    end
    redirect_to :root
  end

  def failure
    case params[:strategy]
    when "cronofy"
      flash[:alert] = "Unable to connect to your calendars: #{params[:message]}"
    when "zendesk"
      flash[:alert] = "Unable to connect to your Zendesk account: #{params[:message]}"
    else
      flash[:error] = "Failure from unrecognised provider"
    end
    redirect_to :root
  end

  def destroy
    logout
    flash[:info] = "Logged out"
    redirect_to :root
  end

  protected

  def auth_hash
    request.env['omniauth.auth']
  end

  def process_cronofy_login(auth_hash)
    user = User.find_or_create_by(cronofy_id: auth_hash['uid'])

    user.email = auth_hash['info']['email']
    user.name = auth_hash['info']['name']
    user.cronofy_access_token = auth_hash['credentials']['token']
    user.cronofy_refresh_token = auth_hash['credentials']['refresh_token']
    user.cronofy_access_token_expiration = Time.at(auth_hash['credentials']['expires_at']).getutc
    user.save

    login(user)
    setup_sync(user)
    SyncMailChimpSubscriberWithUser.perform_later(user.id)
  end

  def process_zendesk_login(auth_hash)
    log.debug { "auth_hash=#{auth_hash.inspect}" }
    current_user.zendesk_user_id = auth_hash['info']['id']
    current_user.zendesk_access_token = auth_hash['credentials']['token']
    current_user.zendesk_time_zone = get_zendesk_client(current_user).current_user.time_zone
    current_user.save

    setup_sync(current_user)
    SyncMailChimpSubscriberWithUser.perform_later(current_user.id)
  end

  def setup_sync(user)
    return unless user.active?

    synchronizer = TaskSynchronizer.new(user)
    callback_url = cronofy_callback_url(id: user.cronofy_id)

    synchronizer.setup_sync(callback_url)
  end

end
