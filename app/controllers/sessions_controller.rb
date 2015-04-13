class SessionsController < ApplicationController
  def create
    log.debug { "#create #{auth_hash.inspect}" }

    case auth_hash['provider']
    when 'cronofy'
      process_cronofy_login(auth_hash)
      flash[:success] = "Connected to your calendars"
    when 'evernote'
      process_evernote_login(auth_hash)
      flash[:success] = "Connected to Evernote"
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
    when "evernote"
      flash[:alert] = "Unable to connect to your Evernote account: #{params[:message]}"
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
    user.cronofy_access_token = auth_hash['credentials']['token']
    user.cronofy_refresh_token = auth_hash['credentials']['refresh_token']
    user.save
    login(user)
  end

  def process_evernote_login(auth_hash)
    log.debug { "auth_hash=#{auth_hash.inspect}" }
    current_user.evernote_user_id = auth_hash['uid']
    current_user.evernote_access_token = auth_hash['credentials']['token']
    current_user.save
  end
end
