module Admin
  class UsersController < BaseController
    include UsersHelper

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

    def users
      @users ||= begin
        if params[:q]
          User.where("email ILIKE ?", "%#{params[:q]}%")
        else
          []
        end
      end
    end

    def user
      @user ||= User.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound
      nil
    end

  end
end