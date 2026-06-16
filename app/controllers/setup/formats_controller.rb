# frozen_string_literal: true

module Setup
  class FormatsController < BaseController
    before_action :set_format, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.formats.view") }, only: %i[index show]
    before_action -> { authorize!("setup.formats.create") }, only: %i[new create]
    before_action -> { authorize!("setup.formats.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.formats.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.formats.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.formats.delete") }, only: :destroy

    def index
      @formats = Format.order(:format_key)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@format).limit(50)
    end

    def new
      @format = Format.new(active: true)
    end

    def create
      @format = Format.new(format_params)
      if @format.save
        record_audit!("format.created", @format)
        redirect_to setup_format_path(@format), notice: "Format created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @format.update(format_params)
        record_audit!("format.updated", @format)
        redirect_to setup_format_path(@format), notice: "Format updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @format.catalog_items.exists?
        redirect_to setup_format_path(@format), alert: "Format cannot be deleted. Inactivate instead."
      else
        @format.destroy
        record_audit!("format.deleted", @format)
        redirect_to setup_formats_path, notice: "Format deleted."
      end
    end

    def inactivate
      @format.inactivate!
      record_audit!("format.inactivated", @format)
      redirect_to setup_format_path(@format), notice: "Format inactivated."
    end

    def reactivate
      @format.reactivate!
      record_audit!("format.reactivated", @format)
      redirect_to setup_format_path(@format), notice: "Format reactivated."
    end

    private

    def set_format
      @format = Format.find(params[:id])
    end

    def format_params
      params.require(:format).permit(:format_key, :name, :short_name, :code, :virtual, :active)
    end
  end
end
