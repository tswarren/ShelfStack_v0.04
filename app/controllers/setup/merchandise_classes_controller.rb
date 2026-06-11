# frozen_string_literal: true

module Setup
  class MerchandiseClassesController < BaseController
    before_action :set_merchandise_class, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.merchandise_classes.view") }, only: %i[index show]
    before_action -> { authorize!("setup.merchandise_classes.create") }, only: %i[new create]
    before_action -> { authorize!("setup.merchandise_classes.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.merchandise_classes.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.merchandise_classes.reactivate") }, only: :reactivate
    before_action :load_form_collections, only: %i[new create edit update]

    def index
      @merchandise_classes = MerchandiseClass.order(:name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@merchandise_class).limit(50)
    end

    def new
      @merchandise_class = MerchandiseClass.new(active: true, has_list_price: true, vendor_discounts_from_list_price: true)
    end

    def create
      @merchandise_class = MerchandiseClass.new(merchandise_class_params)
      if @merchandise_class.save
        record_audit!("merchandise_class.created", @merchandise_class)
        redirect_to setup_merchandise_class_path(@merchandise_class), notice: "Merchandise class created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      if @merchandise_class.update(merchandise_class_params)
        record_audit!("merchandise_class.updated", @merchandise_class)
        redirect_to setup_merchandise_class_path(@merchandise_class), notice: "Merchandise class updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @merchandise_class.categories.exists?
        redirect_to setup_merchandise_class_path(@merchandise_class),
                    alert: "Merchandise class cannot be deleted. Inactivate instead."
      else
        @merchandise_class.destroy
        record_audit!("merchandise_class.deleted", @merchandise_class)
        redirect_to setup_merchandise_classes_path, notice: "Merchandise class deleted."
      end
    end

    def inactivate
      @merchandise_class.inactivate!
      record_audit!("merchandise_class.inactivated", @merchandise_class)
      redirect_to setup_merchandise_class_path(@merchandise_class), notice: "Merchandise class inactivated."
    end

    def reactivate
      @merchandise_class.reactivate!
      record_audit!("merchandise_class.reactivated", @merchandise_class)
      redirect_to setup_merchandise_class_path(@merchandise_class), notice: "Merchandise class reactivated."
    end

    private

    def set_merchandise_class
      @merchandise_class = MerchandiseClass.find(params[:id])
    end

    def load_form_collections
      @tax_categories = TaxCategory.active_records.order(:sort_order, :name)
    end

    def merchandise_class_params
      params.require(:merchandise_class).permit(
        :merchandise_class_key, :name, :short_name, :default_pricing_model, :default_tax_category_id,
        :default_margin_target_bps, :default_supplier_discount_bps, :has_list_price,
        :vendor_discounts_from_list_price, :store_marks_up_from_cost, :vendor_returnable_default,
        :used_sales_allowed, :buyback_allowed, :default_sales_account_code, :active
      )
    end
  end
end
