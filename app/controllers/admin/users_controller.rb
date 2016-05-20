module Admin
  class UsersController < BaseController
    include UsersHelper

    helper_method :users

    def index

    end

    def destroy
      delete_account(user)
      redirect_to admin_users_path
    end

    def users
      @users ||= User.all
    end

    def user
      @user ||= User.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound
      nil
    end

  end
end