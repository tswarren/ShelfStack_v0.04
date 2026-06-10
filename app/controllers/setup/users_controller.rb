# frozen_string_literal: true

module Setup
  class UsersController < BaseController
    before_action :set_user, only: %i[
      show edit update destroy inactivate reactivate reset_password clear_pin assign_role remove_role
    ]
    before_action -> { authorize!("setup.users.view") }, only: %i[index show]
    before_action -> { authorize!("setup.users.create") }, only: %i[new create]
    before_action -> { authorize!("setup.users.update") }, only: %i[edit update reset_password clear_pin]
    before_action -> { authorize!("setup.user_roles.manage") }, only: %i[assign_role remove_role]
    before_action -> { authorize!("setup.users.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.users.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.users.delete") }, only: :destroy

    before_action :load_stores, only: %i[new edit create update show assign_role]
    before_action :load_role_assignment_context, only: %i[show assign_role remove_role]

    def index
      @users = User.order(:username)
      @users = @users.where("username ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    end

    def show
      @audit_events = AuditEvent.for_auditable(@user).limit(50)
      @can_manage_user_roles = Authorization.allowed?(
        user: current_user,
        permission_key: "setup.user_roles.manage",
        store: current_store
      )
    end

    def new
      @user = User.new(user_type: "user", interactive_login_enabled: true, active: true)
    end

    def create
      @user = User.new(user_params)
      @user.password = params[:user][:password] if params[:user][:password].present?

      if @user.save
        record_audit!("user.created", @user)
        redirect_to setup_user_path(@user), notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to setup_user_path(@user), alert: "The system user cannot be edited." if @user.system_user?
    end

    def update
      if @user.system_user?
        redirect_to setup_user_path(@user), alert: "The system user cannot be modified."
        return
      end

      if @user.update(user_params)
        record_audit!("user.updated", @user)
        redirect_to setup_user_path(@user), notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user.system_user? || @user.user_sessions.exists? || @user.audit_events_as_actor.exists?
        redirect_to setup_user_path(@user), alert: "User cannot be deleted. Inactivate instead."
      else
        @user.destroy
        record_audit!("user.deleted", @user)
        redirect_to setup_users_path, notice: "User deleted."
      end
    end

    def inactivate
      if @user.system_user?
        redirect_to setup_user_path(@user), alert: "The system user cannot be inactivated."
        return
      end

      @user.inactivate!
      record_audit!("user.inactivated", @user)
      redirect_to setup_user_path(@user), notice: "User inactivated."
    end

    def reactivate
      @user.reactivate!
      record_audit!("user.reactivated", @user)
      redirect_to setup_user_path(@user), notice: "User reactivated."
    end

    def reset_password
      @user.password = params[:password]
      @user.password_confirmation = params[:password_confirmation]
      @user.force_password_change = true
      if @user.save
        record_audit!("user.password_reset", @user)
        redirect_to setup_user_path(@user), notice: "Password reset."
      else
        redirect_to setup_user_path(@user), alert: @user.errors.full_messages.to_sentence
      end
    end

    def clear_pin
      @user.clear_pin!
      record_audit!("user.pin_cleared", @user)
      redirect_to setup_user_path(@user), notice: "PIN cleared."
    end

    def assign_role
      role = Role.find(params[:role_id])
      scope_type = params[:scope_type].to_s
      store = scope_type == "store" ? Store.find_by(id: params[:store_id]) : nil

      UserRoleAssignmentService.assign!(
        user: @user,
        role: role,
        scope_type: scope_type,
        store: store,
        assigned_by: current_user
      )
      record_audit!(
        "user.role_added",
        @user,
        details: { role_key: role.role_key, scope_type: scope_type, store_id: store&.id }
      )
      redirect_to setup_user_path(@user), notice: "Role assigned."
    rescue ActiveRecord::RecordInvalid, UserRoleAssignmentService::Error, SuperAdministratorProtection::Error => e
      redirect_to setup_user_path(@user), alert: e.message
    end

    def remove_role
      assignment = @user.user_role_assignments.find(params[:assignment_id])
      UserRoleAssignmentService.remove!(assignment: assignment)
      record_audit!(
        "user.role_removed",
        @user,
        details: {
          role_key: assignment.role.role_key,
          scope_type: assignment.scope_type,
          store_id: assignment.store_id
        }
      )
      redirect_to setup_user_path(@user), notice: "Role assignment removed."
    rescue ActiveRecord::RecordInvalid, UserRoleAssignmentService::Error, SuperAdministratorProtection::Error => e
      redirect_to setup_user_path(@user), alert: e.message
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(
        :user_type, :username, :first_name, :last_name, :display_name, :clerk_number,
        :default_store_id, :interactive_login_enabled, :active, :force_password_change
      )
    end

    def load_stores
      @stores = Store.order(:store_number)
    end

    def load_role_assignment_context
      @role_assignments = @user.user_role_assignments.includes(:role, :store, :assigned_by_user)
        .order(active: :desc, assigned_at: :desc, id: :desc)
      @assignable_roles = Role.active_records.order(:name)
    end
  end
end
