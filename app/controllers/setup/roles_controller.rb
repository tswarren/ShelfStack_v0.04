# frozen_string_literal: true

module Setup
  class RolesController < BaseController
    before_action :set_role, only: %i[show edit update destroy inactivate reactivate update_permissions]
    before_action -> { authorize!("setup.roles.view") }, only: %i[index show]
    before_action -> { authorize!("setup.roles.create") }, only: %i[new create]
    before_action -> { authorize!("setup.roles.update") }, only: %i[edit update update_permissions]
    before_action -> { authorize!("setup.roles.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.roles.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.roles.delete") }, only: :destroy
    before_action -> { authorize!("setup.role_permissions.manage") }, only: :update_permissions

    def index
      @roles = Role.order(:name)
    end

    def show
      @permissions = Permission.active_records.order(:permission_group, :permission_key)
      @audit_events = AuditEvent.for_auditable(@role).limit(50)
    end

    def new
      @role = Role.new(active: true)
    end

    def create
      @role = Role.new(role_params)
      if @role.save
        record_audit!("role.created", @role)
        redirect_to setup_role_path(@role), notice: "Role created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @role.update(role_params)
        record_audit!("role.updated", @role)
        redirect_to setup_role_path(@role), notice: "Role updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @role.system_role? || @role.user_role_assignments.exists?
        redirect_to setup_role_path(@role), alert: "Role cannot be deleted. Inactivate instead."
      else
        @role.destroy
        record_audit!("role.deleted", @role)
        redirect_to setup_roles_path, notice: "Role deleted."
      end
    end

    def inactivate
      @role.inactivate!
      record_audit!("role.inactivated", @role)
      redirect_to setup_role_path(@role), notice: "Role inactivated."
    end

    def reactivate
      @role.reactivate!
      record_audit!("role.reactivated", @role)
      redirect_to setup_role_path(@role), notice: "Role reactivated."
    end

    def update_permissions
      permission = Permission.find(params[:permission_id])
      if params[:grant] == "1"
        @role.grant_permission!(permission)
        record_audit!("role.permission_added", @role, details: { permission_key: permission.permission_key })
      else
        @role.revoke_permission!(permission)
        record_audit!("role.permission_removed", @role, details: { permission_key: permission.permission_key })
      end
      redirect_to setup_role_path(@role)
    end

    private

    def set_role
      @role = Role.find(params[:id])
    end

    def role_params
      params.require(:role).permit(:role_key, :name, :description, :active)
    end
  end
end
