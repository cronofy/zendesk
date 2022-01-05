class RootController < ApplicationController
  include UsersHelper

  force_ssl if: :ssl_configured?
  after_action :allow_iframe

  helper_method :zendesk_credentials?,
                :render_cronofy_auth?,
                :render_zendesk_auth?,
                :render_settings?,
                :setup_complete?

  def show
  end

  def redirect
    redirect_to root_path, status: 301
  end

  def not_found
    log.warn { "#not_found - #{request.fullpath}" }

    respond_to do |format|
      format.html { render status: 404 }
      format.all { render nothing: true, status: 404 }
    end
  end

  def render_cronofy_auth?
    !(logged_in? && current_user.cronofy_credentials?)
  end

  def render_zendesk_auth?
    logged_in? && current_user.cronofy_credentials? && !current_user.zendesk_credentials?
  end

  def render_settings?
    logged_in? && current_user.cronofy_credentials? && current_user.zendesk_credentials?
  end

  def zendesk_credentials?
    logged_in? && current_user.zendesk_credentials?
  end

  def setup_complete?
    logged_in? && current_user.cronofy_credentials? && current_user.zendesk_credentials? && current_user.cronofy_calendar_id
  end

  def calendar
    if logged_in?
      current_user.set_cronofy_calendar_id(params[:calendar_id])
      current_user.save

      flash[:info] = "Calendar ID set"

      setup_sync
    else
      flash[:alert] = "Must be connected to your calendar account before we do that"
    end

    redirect_to :root
  end

  def sync
    if current_user.active?
      setup_sync
      flash[:info] = "Note reminders synced"
    end

    redirect_to :root
  end

  def reset
    if logged_in?
      current_user.cronofy_calendar_id = nil
      current_user.zendesk_high_usn = 0
      current_user.save(current_user)

      flash[:info] = "Syncing reset"
    else
      flash[:alert] = "Must be connected to your calendar account before we do that"
    end

    redirect_to :root
  end

  def destroy
    delete_account(current_user)
    logout

    flash[:info] = "Account deleted"

    redirect_to :root
  end

  def setup_zendesk
    if params[:subdomain].blank?
      flash[:alert] = "We need your Zendesk subdomain"
      redirect_to :root
      return
    end

    current_user.zendesk_subdomain = params[:subdomain]
    current_user.save
    session['zendesk_subdomain'] = current_user.zendesk_subdomain
    redirect_to "/auth/zendesk"
  end

  def grouped_calendars
    @grouped_calendars ||= begin
      task_synchronizer.writable_calendars
        .map { |c| [ c.calendar_name, "#{c.profile_name} [#{c.provider_name.titlecase}]", c.calendar_id ] }
        .sort_by { |c| [c[1], c[0].downcase] }
        .group_by { |c| c[1] }
    end
  end

  helper_method :grouped_calendars

  def selected_calendar_info
    @selected_calendar_info ||= task_synchronizer.calendar_info(current_user.cronofy_calendar_id)
  end

  helper_method :selected_calendar_info

  def setup_sync
    callback_url = cronofy_callback_url(id: current_user.cronofy_id)
    task_synchronizer.setup_sync(callback_url)
  end

  def task_synchronizer
    @task_synchronizer ||= TaskSynchronizer.new(current_user)
  end

private

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end
end
