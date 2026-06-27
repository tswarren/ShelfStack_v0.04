# frozen_string_literal: true

module Items
  class SetupModalsController < BaseController
    include Interaction::ModalStreamable
    include Items::SetupModalLocals

    before_action -> { authorize!("items.catalog_items.update") }, only: %i[create_identifier update_identifier]
    before_action -> { authorize!("items.product_variants.update") }, only: %i[update_price update_classification classification_tax_preview]
    before_action -> { authorize!("setup.product_vendors.create") }, only: :create_product_vendor
    before_action -> { authorize!("setup.product_vendors.update") }, only: :update_product_vendor
    before_action -> { authorize!("setup.product_variant_vendors.create") }, only: :create_variant_vendor
    before_action -> { authorize!("setup.product_variant_vendors.update") }, only: :update_variant_vendor

    def create_identifier
      catalog_item = CatalogItem.find(params.require(:catalog_item_id))
      identifier = CatalogIdentifierService.add_identifier!(
        catalog_item: catalog_item,
        identifier_type: params.require(:identifier_type),
        value: params.require(:identifier_value),
        primary: ActiveModel::Type::Boolean.new.cast(params[:primary]),
        actor: current_user
      )
      record_audit!("catalog_item_identifier.created", identifier)
      item = ItemPresenter.from_catalog_item(catalog_item)
      render_modal_success(
        section_target: "catalog-setup-section",
        section_partial: "items/items/catalog",
        section_locals: catalog_setup_locals(item),
        message: "Identifier added.",
        modal_id: "item-identifier-modal"
      )
    rescue ActionController::ParameterMissing, CatalogIdentifierService::IdentifierError => e
      render_identifier_error(catalog_item: catalog_item, message: e.message)
    end

    def update_identifier
      catalog_item = CatalogItem.find(params.require(:catalog_item_id))
      identifier = catalog_item.catalog_item_identifiers.find(params.require(:id))
      CatalogIdentifierService.update_identifier!(
        identifier: identifier,
        value: params.require(:identifier_value),
        actor: current_user
      )
      if ActiveModel::Type::Boolean.new.cast(params[:primary])
        CatalogIdentifierService.set_primary!(identifier: identifier.reload, actor: current_user)
      end
      item = ItemPresenter.from_catalog_item(catalog_item)
      render_modal_success(
        section_target: "catalog-setup-section",
        section_partial: "items/items/catalog",
        section_locals: catalog_setup_locals(item),
        message: "Identifier updated.",
        modal_id: "item-identifier-modal"
      )
    rescue CatalogIdentifierService::IdentifierError => e
      render_identifier_error(catalog_item: catalog_item, identifier: identifier, message: e.message)
    end

    def update_price
      variant = ProductVariant.find(params.require(:variant_id))
      variant.assign_attributes(selling_price_cents: params.require(:selling_price_cents))
      if variant.save
        record_audit!("product_variant.updated", variant)
        item = item_from_variant(variant)
        render_modal_success(
          section_target: "selling-setup-section",
          section_partial: "items/items/selling",
          section_locals: selling_setup_locals(item, highlight_variant: variant),
          message: "Price updated.",
          modal_id: "item-price-modal"
        )
      else
        render_price_error(variant: variant)
      end
    end

    def create_product_vendor
      product = Product.find(params.require(:product_id))
      product_vendor = ProductVendor.new(product_vendor_params)
      product_vendor.product = product
      if product_vendor.save
        record_audit!("product_vendor.created", product_vendor)
        item = ItemPresenter.from_product(product)
        render_modal_success(
          section_target: "vendor-sourcing",
          section_partial: "items/items/display",
          section_locals: display_setup_locals(item),
          message: "Product vendor created.",
          modal_id: "item-product-vendor-modal"
        )
      else
        render_product_vendor_error(product: product, product_vendor: product_vendor)
      end
    end

    def update_product_vendor
      product_vendor = ProductVendor.find(params.require(:id))
      if product_vendor.update(product_vendor_params)
        record_audit!("product_vendor.updated", product_vendor)
        item = ItemPresenter.from_product(product_vendor.product)
        render_modal_success(
          section_target: "vendor-sourcing",
          section_partial: "items/items/display",
          section_locals: display_setup_locals(item),
          message: "Product vendor updated.",
          modal_id: "item-product-vendor-modal"
        )
      else
        render_product_vendor_error(product: product_vendor.product, product_vendor: product_vendor)
      end
    end

    def create_variant_vendor
      variant = ProductVariant.find(params.require(:product_variant_id))
      variant_vendor = ProductVariantVendor.new(variant_vendor_params)
      variant_vendor.product_variant = variant
      if variant_vendor.save
        record_audit!("product_variant_vendor.created", variant_vendor)
        item = item_from_variant(variant)
        render_modal_success(
          section_target: "vendor-sourcing",
          section_partial: "items/items/display",
          section_locals: display_setup_locals(item, highlight_variant: variant),
          message: "Variant vendor override created.",
          modal_id: "item-variant-vendor-modal"
        )
      else
        render_variant_vendor_error(variant: variant, variant_vendor: variant_vendor)
      end
    end

    def update_variant_vendor
      variant_vendor = ProductVariantVendor.find(params.require(:id))
      if variant_vendor.update(variant_vendor_params)
        record_audit!("product_variant_vendor.updated", variant_vendor)
        item = item_from_variant(variant_vendor.product_variant)
        render_modal_success(
          section_target: "vendor-sourcing",
          section_partial: "items/items/display",
          section_locals: display_setup_locals(item, highlight_variant: variant_vendor.product_variant),
          message: "Variant vendor override updated.",
          modal_id: "item-variant-vendor-modal"
        )
      else
        render_variant_vendor_error(variant: variant_vendor.product_variant, variant_vendor: variant_vendor)
      end
    end

    def update_classification
      variant = ProductVariant.find(params.require(:variant_id))
      if variant.update(sub_department_id: params.require(:sub_department_id))
        VariantClassificationSetup.apply!(variant: variant)
        record_audit!("product_variant.updated", variant)
        item = item_from_variant(variant)
        render_modal_success(
          section_target: "vendor-sourcing",
          section_partial: "items/items/display",
          section_locals: display_setup_locals(item, highlight_variant: variant),
          message: "Classification updated.",
          modal_id: "item-classification-modal"
        )
      else
        render_classification_error(variant: variant)
      end
    end

    def classification_tax_preview
      variant = ProductVariant.find(params.require(:variant_id))
      variant.assign_attributes(sub_department_id: params[:sub_department_id]) if params[:sub_department_id].present?
      defaults = ClassificationDefaultsResolver.for(variant: variant, store: current_store)
      render partial: "items/setup_modals/classification_tax_preview_frame",
             locals: { defaults: defaults },
             layout: false
    end

    private

    def product_vendor_params
      params.require(:product_vendor).permit(:vendor_id, :vendor_item_number, :supplier_discount_bps, :preferred)
    end

    def variant_vendor_params
      params.require(:product_variant_vendor).permit(
        :vendor_id, :vendor_item_number, :supplier_discount_bps, :returnability_status, :preferred
      )
    end

    def render_modal_success(section_target:, section_partial:, section_locals:, message:, modal_id:)
      render turbo_stream: modal_success_streams(
        section_target: section_target,
        section_partial: section_partial,
        section_locals: section_locals,
        message: message,
        modal_id: modal_id
      )
    end

    def render_identifier_error(catalog_item:, message:, identifier: nil)
      catalog_item ||= CatalogItem.find_by(id: params[:catalog_item_id])
      modal_error_streams(
        body_target: "item-identifier-modal-body",
        body_partial: "items/setup_modals/identifier_quick_form",
        body_locals: {
          catalog_item: catalog_item,
          identifier: identifier,
          error_message: message
        }
      )
    end

    def render_price_error(variant:)
      modal_error_streams(
        body_target: "item-price-modal-body",
        body_partial: "items/setup_modals/price_quick_form",
        body_locals: { variant: variant }
      )
    end

    def render_product_vendor_error(product:, product_vendor:)
      modal_error_streams(
        body_target: "item-product-vendor-modal-body",
        body_partial: "items/setup_modals/product_vendor_quick_form",
        body_locals: {
          product: product,
          product_vendor: product_vendor,
          vendors: Vendor.active_records.order(:name)
        }
      )
    end

    def render_variant_vendor_error(variant:, variant_vendor:)
      modal_error_streams(
        body_target: "item-variant-vendor-modal-body",
        body_partial: "items/setup_modals/variant_vendor_quick_form",
        body_locals: {
          variant: variant,
          variant_vendor: variant_vendor,
          vendors: Vendor.active_records.order(:name),
          returnability_options: ReturnabilityStatus::RETURNABILITY_STATUSES
        }
      )
    end

    def render_classification_error(variant:)
      modal_error_streams(
        body_target: "item-classification-modal-body",
        body_partial: "items/setup_modals/classification_quick_form",
        body_locals: {
          variant: variant,
          sub_departments: SubDepartment.active_records.order(:name),
          defaults: ClassificationDefaultsResolver.for(variant: variant, store: current_store)
        }
      )
    end
  end
end
