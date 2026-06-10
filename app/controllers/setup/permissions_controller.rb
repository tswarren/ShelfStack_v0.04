# frozen_string_literal: true

module Setup
  class PermissionsController < BaseController
    before_action -> { authorize!("setup.permissions.view") }

    def index
      @permissions = Permission.order(:permission_group, :permission_key)
      @permissions = @permissions.where(permission_group: params[:group]) if params[:group].present?
    end
  end
end
