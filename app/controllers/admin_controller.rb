class AdminController < ApplicationController

  before_action :verify_admin

  helper_method :users

  def index

  end

  def delete_account
    unless user = User.find(params[:user_id])
      render text: "Not Found", status: 404
      return
    end

    UnsubscribeUserFromMailChimp.perform_later(user.email)

    user.destroy!
    logout

    flash[:info] = "Account deleted"

    redirect_to admin_path
  end

  def verify_admin
    unless current_user && current_user.admin?
      redirect_to not_found_path
    end
  end

  def users
    @users ||= User.all.sort { |a, b| b.id <=> a.id }
  end
end