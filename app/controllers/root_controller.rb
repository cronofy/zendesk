class RootController < ApplicationController
  def show
  end

  def calendar
    if logged_in?
      current_user.set_cronofy_calendar_id(params[:calendar_id])
      current_user.save(current_user)
      flash[:info] = "Calendar ID set"
      # pre-emptively perform a sync
      sync
    else
      flash[:alert] = "Must be connected to your calendar account before we do that"
      redirect_to :root
    end
  end

  def sync
    SyncRemindersFromEvernote.new.perform(current_user.id)
    SyncRemindersFromCronofy.new.perform(current_user.id)

    if ENV["CALLBACKS_ENABLED"].to_i > 0
      callback_url = cronofy_callback_url(id: current_user.cronofy_id)
      reminder_synchronizer.create_cronofy_notification_channel(callback_url)
    end

    flash[:info] = "Note reminders synced"

    redirect_to :root
  end

  def reset
    if logged_in?
      current_user.cronofy_calendar_id = nil
      current_user.evernote_high_usn = 0
      current_user.save(current_user)

      flash[:info] = "Syncing reset"
    else
      flash[:alert] = "Must be connected to your calendar account before we do that"
    end

    redirect_to :root
  end

  def destroy
    current_user.destroy!
    logout

    flash[:info] = "Account deleted"

    redirect_to :root
  end

  def grouped_calendars
    @grouped_calendars ||= begin
      reminder_synchronizer.writable_calendars
        .map { |c| [ c.calendar_name, "#{c.profile_name} [#{c.provider_name.titlecase}]", c.calendar_id ] }
        .sort_by { |c| [c[1], c[0].downcase] }
        .group_by { |c| c[1] }
    end
  end

  helper_method :grouped_calendars

  def reminder_synchronizer
    @reminder_synchronizer ||= ReminderSynchronizer.new(current_user)
  end
end
