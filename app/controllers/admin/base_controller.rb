module Admin
  class BaseController < ApplicationController

    layout 'layouts/admin'

    before_action :verify_admin

    def verify_admin
      unless current_user && current_user.admin?
        not_found && return
      end
    end

  end
end