module Admin
  class UsersController < BaseController
    include UsersHelper
    include ZendeskApiClient

    helper_method :user, :users

    def index

    end

    def update
      not_found && return unless user

      user.debug_enabled = params[:debug_enabled].to_i > 0
      user.is_admin = params[:is_admin].to_i > 0
      user.save

      redirect_to admin_user_path(user.id)
    end

    def destroy
      delete_account(user)
      redirect_to admin_users_path
    end

    def sync_zendesk_settings
      if zendesk_user = get_zendesk_client(user).current_user
        user.zendesk_time_zone = zendesk_user.time_zone
        user.save
      else
        flash[:danger] = "Failed to get zendesk user for user_id=#{user.id}"
        log.warning "#sync_zendesk_settings failed for user_id=#{user.id}"
      end

      redirect_to admin_user_path(user.id)
    end

    def users
      @users ||= begin
        if !params[:email].blank?
          User.where("email ILIKE ?", "%#{params[:email]}%")
        elsif !params[:zendesk_subdomain].blank?
          User.where("zendesk_subdomain ILIKE ?", "%#{params[:zendesk_subdomain]}%")
        else
          []
        end
      end
    end

    def user
      @user ||= User.find((params[:id] || params[:user_id]).to_i)
    rescue ActiveRecord::RecordNotFound
      nil
    end

  end
end