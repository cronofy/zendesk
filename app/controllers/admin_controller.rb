class AdminController < ApplicationController

  before_action :verify_admin

  helper_method :users

  def index

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