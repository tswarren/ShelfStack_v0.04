# frozen_string_literal: true

module Items
  class AddItemController < BaseController
    include ProductBisacSyncable

    STEPS = %w[choose_path identify item_details selling_setup sellable_sku].freeze
    WORKFLOWS = %w[catalog_linked non_catalog].freeze

    before_action :load_step
    before_action :load_draft
    before_action :capture_match_context!
    before_action :authorize_step!

    def new
      reset_draft!
      redirect_to items_add_item_path(step: "choose_path")
    end

    def create
      case @step
      when "choose_path" then handle_choose_path
      when "identify" then handle_identify
      when "item_details" then handle_item_details
      when "selling_setup" then handle_selling_setup
      when "sellable_sku" then handle_sellable_sku
      else
        redirect_to items_root_path, alert: "Unknown wizard step."
      end
    end

    def show
      render_step
    end

    private

    def load_step
      @step = params[:step].presence || "choose_path"
      redirect_to items_root_path, alert: "Unknown wizard step." unless STEPS.include?(@step)
    end

    def load_draft
      @draft = session[:add_item_draft] ||= {}
    end

    def reset_draft!
      session[:add_item_draft] = {}
    end

    def save_draft!(attrs)
      session[:add_item_draft] = @draft.merge(attrs.stringify_keys)
      @draft = session[:add_item_draft]
    end

    def authorize_step!
      case @step
      when "choose_path"
        authorize!("items.access")
      when "identify"
        authorize!("items.external_lookup.access")
      when "item_details"
        authorize!("items.catalog_items.create")
      when "selling_setup"
        authorize!("items.products.create")
      when "sellable_sku"
        authorize!("items.product_variants.create")
      end
    end

    def catalog_linked?
      @draft["workflow"] == "catalog_linked"
    end

    def non_catalog?
      @draft["workflow"] == "non_catalog"
    end

    def render_step
      @match_context = load_match_context
      case @step
      when "choose_path"
        render "items/add_item/choose_path"
      when "identify"
        ensure_catalog_linked_workflow! or return
        @local_product = local_match_product
        @local_match_variant = local_match_variant_for_request
        render "items/add_item/identify"
      when "item_details"
        ensure_catalog_linked_workflow! or return
        @external_lookup_staged = external_lookup_staged?
        @product = find_or_build_product
        @formats = Format.active_records.order(:name)
        load_bisac_form_state(@product)
        load_store_category_collections
        render "items/add_item/item_details"
      when "selling_setup"
        if params[:generate_sku].present?
          save_draft!("generated_sku" => AddItem::ProductSkuGenerator.generate!)
          redirect_to items_add_item_path(step: "selling_setup") and return
        end
        if catalog_linked?
          ensure_product_metadata_in_draft! or return
        else
          ensure_non_catalog_workflow! or return
        end
        prepare_selling_setup_form
        render "items/add_item/selling_setup"
      when "sellable_sku"
        ensure_product_in_draft! or return
        @product = Product.find(@draft["product_id"])
        prepare_sellable_sku_form
        render "items/add_item/sellable_sku"
      end
    end

    def handle_choose_path
      workflow = params.require(:workflow)
      unless WORKFLOWS.include?(workflow)
        redirect_to items_add_item_path(step: "choose_path"), alert: "Choose a valid item type."
        return
      end

      save_draft!("workflow" => workflow)
      if workflow == "catalog_linked"
        redirect_to items_add_item_path(step: "identify")
      else
        redirect_to items_add_item_path(step: "selling_setup")
      end
    end

    def handle_identify
      ensure_catalog_linked_workflow! or return
      redirect_to items_add_item_path(step: "identify")
    end

    def local_match_product
      return unless @draft["product_id"].present?

      Product.find_by(id: @draft["product_id"])
    end

    def local_match_variant_for_request
      product = @local_product || local_match_product
      return if product.blank?

      product.product_variants.active_records.order(:id).first
    end

    def add_item_cancel_path
      context = load_match_context
      return context.return_path if context.valid?

      items_root_path
    end

    def handle_item_details
      ensure_catalog_linked_workflow! or return
      @formats = Format.active_records.order(:name)
      load_store_category_collections
      @external_lookup_staged = external_lookup_staged?

      cover_image_url = external_lookup_result&.image_url if @external_lookup_staged
      sku_validation = nil

      if @draft["product_id"].present?
        @product = Product.find(@draft["product_id"])
        @product.assign_attributes(product_metadata_params)
        saved = persist_product_updates!(@product)
        created = false
      else
        @product = Product.new(
          product_metadata_params.merge(
            active: true,
            publication_status: "active",
            product_type: "physical",
            variation_type: "conditional"
          )
        )
        saved, sku_validation, identifier_result = save_product!(@product)
        created = saved
      end
      return unless saved

      finalize_external_lookup_import!(@product) if @external_lookup_staged

      bisac_result = sync_product_bisac!(@product)
      store_category_result = sync_product_store_category!(@product)
      record_audit!(created ? "product.created" : "product.updated", @product)
      apply_bisac_sync_notice!(bisac_result)
      apply_store_category_sync_notice!(store_category_result)
      apply_initial_identifier_notice!(identifier_result, sku_validation)
      draft_attrs = {
        "product_id" => @product.id,
        "external_lookup_result_id" => nil,
        "external_lookup_format_id" => nil
      }
      draft_attrs["external_lookup_cover_image_url"] = cover_image_url if cover_image_url.present?
      if external_lookup_result&.msrp_cents.present?
        draft_attrs["external_lookup_msrp_cents"] = external_lookup_result.msrp_cents
      end
      save_draft!(draft_attrs)

      if done_commit?
        reset_draft!
        redirect_to ItemPresenter.from_product(@product).show_path,
                    notice: "Item details saved. Status: Product Only."
      else
        redirect_to items_add_item_path(step: "selling_setup")
      end
    end

    def handle_selling_setup
      if params[:generate_sku].present?
        ensure_non_catalog_workflow! or return
        save_draft!("generated_sku" => AddItem::ProductSkuGenerator.generate!)
        redirect_to items_add_item_path(step: "selling_setup")
        return
      end

      if catalog_linked?
        ensure_product_metadata_in_draft! or return
      else
        ensure_non_catalog_workflow! or return
      end

      @product = build_product_from_params
      load_product_collections

      if @product.save
        cover_import_message = import_external_cover_image!(@product)
        record_audit!(catalog_linked? ? "product.updated" : "product.created", @product)
        draft_updates = { "product_id" => @product.id, "external_lookup_msrp_cents" => nil }
        draft_updates["external_lookup_cover_image_url"] = nil if cover_import_message.nil?
        save_draft!(draft_updates)

        notice = if done_commit?
                   "Selling setup saved. Add a sellable SKU when ready."
        else
                   nil
        end
        notice = [ notice, cover_import_message ].compact.join(" ") if cover_import_message.present?

        if done_commit?
          reset_draft!
          redirect_to ItemPresenter.from_product(@product).show_path, notice: notice.presence
        else
          redirect_to items_add_item_path(step: "sellable_sku"),
                      notice: notice.presence || "Selling setup saved."
        end
      else
        @step = "selling_setup"
        load_product_collections
        render "items/add_item/selling_setup", status: :unprocessable_entity
      end
    end

    def handle_sellable_sku
      ensure_product_in_draft!
      @product = Product.find(@draft["product_id"])
      @variant = ProductVariant.new(
        product_variant_params.except(:inventory_tracking).merge(
          product: @product,
          active: true
        )
      )
      if params.dig(:product_variant, :inventory_tracking).present?
        Items::InventoryTrackingSync.apply_tracking_selection!(
          variant: @variant,
          tracking: params.dig(:product_variant, :inventory_tracking)
        )
      else
        Items::InventoryTrackingSync.seed_defaults_from_product!(variant: @variant)
      end
      @variant.condition ||= default_condition if condition_variation_product?(@product)
      VariantClassificationSetup.apply!(variant: @variant)
      prepare_sellable_sku_form

      if @variant.save
        record_audit!("product_variant.created", @variant, details: { "sku" => @variant.sku })

        if add_another_commit?
          redirect_to items_add_item_path(step: "sellable_sku"),
                      notice: "Sellable SKU created. Add another or cancel to finish."
        elsif customer_request_match_draft.present?
          match_customer_request_line!(@variant)
        elsif buyback_line_match_draft.present?
          match_buyback_line!(@variant)
        else
          reset_draft!
          redirect_to ItemPresenter.from_product(@product).show_path, notice: "Item added successfully."
        end
      else
        @step = "sellable_sku"
        render "items/add_item/sellable_sku", status: :unprocessable_entity
      end
    end

    def save_product!(product)
      sku_validation = nil
      identifier_result = nil
      saved = false
      lookup_result = external_lookup_result
      begin
        Product.transaction do
          unless product.persisted?
            sku_validation = assign_transitional_sku!(product, lookup_result: lookup_result)
          end
          raise ActiveRecord::Rollback unless product.save

          saved = product.sku.present?
          raise ActiveRecord::Rollback unless saved

          if product.product_identifiers.active_records.none?
            identifier_result = persist_initial_product_identifier!(product, lookup_result: lookup_result)
          end
        end
      rescue AddItem::TransitionalSkuAssigner::ConflictError => e
        product.errors.add(:base, e.message)
        saved = false
      rescue ProductIdentifierService::IdentifierError => e
        product.errors.add(:base, e.message)
        saved = false
      rescue ActiveRecord::RecordInvalid => e
        product.errors.merge!(e.record.errors) unless e.record == product
        saved = false
      end

      render_item_details_errors(product) unless saved

      [ saved, sku_validation, identifier_result ]
    end

    def persist_product_updates!(product)
      return true if product.save

      render_item_details_errors(product)
      false
    end

    def assign_transitional_sku!(product, lookup_result: nil)
      if lookup_result.present?
        AddItem::TransitionalSkuAssigner.assign!(product: product, candidate: lookup_result, actor: current_user)
      elsif identifier_value_param.present?
        AddItem::TransitionalSkuAssigner.assign!(
          product: product,
          identifier_type: identifier_type_param,
          identifier_value: identifier_value_param,
          actor: current_user
        )
      else
        AddItem::TransitionalSkuAssigner.assign!(product: product, actor: current_user)
      end
    end

    def finalize_external_lookup_import!(product)
      lookup_result = external_lookup_result
      return if lookup_result.blank?

      ExternalCatalog::ImportCandidate.finalize_create!(
        lookup_result: lookup_result,
        product: product,
        actor: current_user
      )
    end

    def external_lookup_staged?
      @draft["external_lookup_result_id"].present? && @draft["product_id"].blank?
    end

    def external_lookup_result
      return unless @draft["external_lookup_result_id"].present?

      ExternalLookupResult.find_by(id: @draft["external_lookup_result_id"])
    end

    def import_external_cover_image!(product)
      return if cover_image_uploaded?
      return if @draft["external_lookup_cover_image_url"].blank?

      result = ExternalCatalog::CoverImageImporter.call(
        product: product,
        url: @draft["external_lookup_cover_image_url"],
        actor: current_user
      )
      return nil if result.attached

      result.message
    end

    def cover_image_uploaded?
      params.dig(:product, :cover_image).present?
    end

    def external_lookup_msrp_cents
      @draft["external_lookup_msrp_cents"].to_i
    end

    def prepare_selling_setup_form
      load_product_collections

      if catalog_linked?
        ensure_product_metadata_in_draft!
        @product = Product.find(@draft["product_id"])
        @product.assign_attributes(
          list_price_cents: @product.list_price_cents.to_i.positive? ? @product.list_price_cents : external_lookup_msrp_cents,
          default_sub_department_id: @product.default_sub_department_id,
          default_display_location_id: @product.default_display_location_id
        )
        apply_store_category_product_defaults!(@product)
      else
        @product = Product.new(
          active: true,
          product_type: "physical",
          variation_type: "standard",
          sku: @draft["generated_sku"],
          list_price_cents: 0
        )
      end
    end

    def build_product_from_params
      if catalog_linked?
        product = Product.find(@draft["product_id"])
        attrs = product_params.to_h.symbolize_keys
        attrs[:variation_type] = resolved_variation_type(attrs[:product_type], attrs[:variation_type].presence || "conditional")
        attrs.delete(:name)
        attrs.delete(:sku) if attrs[:sku].blank?
        product.assign_attributes(attrs)
        apply_store_category_product_defaults!(product)
        product.default_inventory_tracking ||= AddItem::InventoryTrackingMapper.for_product_type(product.product_type)
        product
      else
        attrs = product_params.to_h.symbolize_keys
        attrs[:active] = true
        attrs[:variation_type] = resolved_variation_type(attrs[:product_type], attrs[:variation_type])
        attrs.delete(:name_override)
        Product.new(attrs).tap do |built|
          built.default_inventory_tracking ||= AddItem::InventoryTrackingMapper.for_product_type(built.product_type)
        end
      end
    end

    def apply_store_category_product_defaults!(target)
      defaults = StoreCategoryDefaults.for(store_category_node: target.is_a?(Product) ? target.store_category : nil)
      return if defaults.source == "none"

      if target.is_a?(Hash)
        if defaults.default_sub_department.present? && target[:default_sub_department_id].blank?
          target[:default_sub_department_id] = defaults.default_sub_department.id
        end
        if defaults.default_display_location.present? && target[:default_display_location_id].blank?
          target[:default_display_location_id] = defaults.default_display_location.id
        end
      else
        target.default_sub_department ||= defaults.default_sub_department if defaults.default_sub_department.present?
        target.default_display_location ||= defaults.default_display_location if defaults.default_display_location.present?
      end
    end

    def resolved_variation_type(_product_type, variation_type)
      variation_type.presence || "standard"
    end

    def prepare_sellable_sku_form
      load_variant_collections
      @variant ||= ProductVariant.new(product: @product, active: true)
      if condition_variation_product?(@product)
        condition = @variant.condition || default_condition
        @variant.condition_id ||= condition&.id
        @variant.condition ||= condition
      end
      @variant.sub_department_id ||= @product.default_sub_department_id.presence || @sub_departments.first&.id
      Items::InventoryTrackingSync.seed_defaults_from_product!(variant: @variant) unless sellable_sku_params_submitted?
      VariantClassificationSetup.apply!(variant: @variant) unless sellable_sku_params_submitted?
      apply_variant_defaults! unless sellable_sku_params_submitted?
    end

    def sellable_sku_params_submitted?
      params[:product_variant].present?
    end

    def apply_variant_defaults!
      condition = condition_variation_product?(@product) ? (@variant.condition || default_condition) : @variant.condition
      if @variant.selling_price_cents.to_i.zero?
        @variant.selling_price_cents = AddItem::DefaultSellingPrice.cents(product: @product, condition: condition)
      end
    end

    def condition_variation_product?(product = @product)
      product.variation_type.in?(%w[standard conditional])
    end

    def default_condition
      ProductCondition.active_records.find_by(new_condition: true) ||
        ProductCondition.active_records.order(:sort_order).first
    end

    def find_or_build_product
      if external_lookup_staged?
        lookup_result = external_lookup_result
        format = Format.active_records.find_by(id: @draft["external_lookup_format_id"])
        ExternalCatalog::StagedProductBuilder.build(lookup_result:, format:)
      elsif @draft["product_id"].present?
        Product.find(@draft["product_id"])
      else
        Product.new(active: true, publication_status: "active", catalog_item_type: "book", product_type: "physical", variation_type: "conditional")
      end
    end

    def ensure_catalog_linked_workflow!
      return true if catalog_linked?

      redirect_to items_add_item_path(step: "choose_path"), alert: "Choose catalog-linked item to continue."
      false
    end

    def ensure_non_catalog_workflow!
      return true if non_catalog?

      redirect_to items_add_item_path(step: "choose_path"), alert: "Choose non-catalog item to continue."
      false
    end

    def ensure_product_metadata_in_draft!
      return true if @draft["product_id"].present?

      redirect_to items_add_item_path(step: "item_details"), alert: "Complete item details first."
      false
    end

    def ensure_product_in_draft!
      return true if @draft["product_id"].present?

      redirect_to items_add_item_path(step: "selling_setup"), alert: "Complete selling setup first."
      false
    end

    def load_store_category_collections
      @store_category_scheme = CategoryScheme.active_records.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      @store_category_nodes = if @store_category_scheme
                                CategoryNode.active_for_tree_select(@store_category_scheme)
      else
                                CategoryNode.none
      end
    end

    def load_product_collections
      @sub_departments = SubDepartment.active_records.order(:name)
      @display_locations = DisplayLocation.active_for_tree_select
    end

    def load_variant_collections
      load_product_collections
      @conditions = ProductCondition.active_records.order(:sort_order, :name)
    end

    def product_metadata_params
      source = params[:product].presence || params[:catalog_item]
      params_hash = source.is_a?(ActionController::Parameters) ? source : ActionController::Parameters.new(source || {})
      params_hash.permit(
        :catalog_item_type, :title, :creators, :publisher, :publication_date, :publication_status,
        :series_name, :series_enumeration, :format_id, :edition_statement, :language_code,
        :height, :width, :depth, :dimension_units, :weight, :weight_units, :page_count,
        :duration_minutes, :large_print, :bisac_subjects, :genres, :themes, :target_audiences,
        :access_restrictions, :publication_frequency, :description, :year, :digital, :active,
        :store_category_id
      )
    end

    def product_params
      params.require(:product).permit(
        :name, :name_override, :sku, :product_type, :variation_type, :list_price_cents,
        :default_display_location_id, :default_sub_department_id, :variant1_label, :variant2_label,
        :cover_image
      )
    end

    def product_variant_params
      params.require(:product_variant).permit(
        :condition_id, :sub_department_id, :selling_price_cents, :display_location_id, :sku,
        :name_override, :attribute1_value, :attribute1_sku_component,
        :attribute2_value, :attribute2_sku_component, :inventory_tracking
      )
    end

    def sync_product_store_category!(product)
      ProductStoreCategorySync.apply!(
        product: product,
        store_category_id: product_metadata_params_source[:store_category_id],
        bisac_category_node_ids: params[:bisac_category_node_ids]
      )
    end

    def apply_store_category_sync_notice!(result)
      return if result.warnings.blank?

      flash.now[:alert] = [ flash.now[:alert], result.warnings.join(" ") ].compact.join(" ")
    end

    def identifier_type_param
      product_metadata_params_source[:initial_identifier_type].presence || "isbn13"
    end

    def identifier_value_param
      product_metadata_params_source[:initial_identifier_value].to_s.strip
    end

    def persist_initial_product_identifier!(product, lookup_result: nil)
      type = identifier_type_param
      value = identifier_value_param
      if value.blank? && lookup_result.present?
        value = lookup_result.isbn13.presence || lookup_result.isbn10.presence
        type = lookup_result.isbn13.present? ? "isbn13" : "isbn10"
      end

      Items::PersistInitialProductIdentifier.call(
        product: product,
        identifier_type: type,
        identifier_value: value,
        actor: current_user,
        source: "add_item_wizard"
      )
    end

    def apply_initial_identifier_notice!(identifier_result, sku_validation)
      if identifier_result&.identifier.present?
        apply_identifier_validation_notice!(identifier_result.identifier)
      else
        apply_transitional_identifier_notice!(sku_validation&.validation_message)
      end
    end

    def apply_identifier_validation_notice!(record)
      identifier = record.is_a?(ProductIdentifier) ? record : record.reload.primary_identifier
      return if identifier.blank? || identifier.validation_message.blank?

      message = "Identifier saved with warning: #{identifier.validation_message}"
      flash[:warning] = [ flash[:warning], message ].compact.join(" ")
    end

    def render_item_details_errors(product)
      @step = "item_details"
      @product = product
      @external_lookup_staged = external_lookup_staged?
      load_bisac_form_state(product)
      load_store_category_collections
      render "items/add_item/item_details", status: :unprocessable_entity
    end

    def done_commit?
      params[:commit].to_s.casecmp("done").zero?
    end

    def add_another_commit?
      params[:commit].to_s.include?("Add Another")
    end

    def capture_match_context!
      if params[:return_to].to_s == Buybacks::LineMatchContext::RETURN_TO
        return if params[:buyback_session_id].blank? || params[:line_id].blank?

        save_draft!(
          "return_to" => params[:return_to],
          "buyback_session_id" => params[:buyback_session_id],
          "buyback_line_id" => params[:line_id]
        )
        return
      end

      return unless params[:return_to].to_s == Customers::RequestMatchContext::RETURN_TO
      return if params[:customer_request_id].blank? || params[:line_id].blank?

      save_draft!(
        "return_to" => params[:return_to],
        "customer_request_id" => params[:customer_request_id],
        "customer_request_line_id" => params[:line_id]
      )
    end

    def buyback_line_match_draft
      return nil unless @draft["return_to"] == Buybacks::LineMatchContext::RETURN_TO
      return nil if @draft["buyback_session_id"].blank? || @draft["buyback_line_id"].blank?

      @draft
    end

    def match_buyback_line!(variant)
      context = Buybacks::LineMatchContext.from_draft(@draft, store: current_store)
      session = context.session_record
      line = context.line
      Buybacks::SelectVariant.call!(line: line, session: session, variant: variant, actor: current_user)
      reset_draft!
      redirect_to buybacks_session_path(session, open_line: line.id, anchor: "line-#{line.id}"),
                  notice: "Item added and matched to buyback line."
    rescue Buybacks::SelectVariant::Error => e
      reset_draft!
      redirect_to ItemPresenter.from_product(@product).show_path, alert: e.message
    end

    def customer_request_match_draft
      return nil unless @draft["return_to"] == Customers::RequestMatchContext::RETURN_TO
      return nil if @draft["customer_request_id"].blank? || @draft["customer_request_line_id"].blank?

      @draft
    end

    def match_customer_request_line!(variant)
      request = CustomerRequest.find(customer_request_match_draft["customer_request_id"])
      line = request.customer_request_lines.find(customer_request_match_draft["customer_request_line_id"])
      CustomerRequests::MatchVariant.call!(line: line, variant: variant, actor: current_user)
      reset_draft!
      redirect_to customers_customer_request_path(request, anchor: "line-#{line.id}"),
                  notice: "Item added and matched to request line."
    rescue CustomerRequests::MatchVariant::MatchError => e
      reset_draft!
      redirect_to ItemPresenter.from_product(@product).show_path, alert: e.message
    end

    def load_match_context
      if buyback_line_match_draft.present?
        return Buybacks::LineMatchContext.from_draft(@draft, store: current_store)
      end

      draft = customer_request_match_draft
      unless draft
        return Customers::RequestMatchContext.new(return_to: "", customer_request_id: nil, line_id: nil, store: current_store)
      end

      Customers::RequestMatchContext.new(
        return_to: draft["return_to"],
        customer_request_id: draft["customer_request_id"],
        line_id: draft["customer_request_line_id"],
        store: current_store
      )
    end

    def add_item_match_params
      if buyback_line_match_draft.present?
        return Buybacks::LineMatchContext.from_draft(@draft, store: current_store).param_hash
      end

      draft = customer_request_match_draft
      return {} unless draft

      {
        return_to: draft["return_to"],
        customer_request_id: draft["customer_request_id"],
        line_id: draft["customer_request_line_id"]
      }
    end
    helper_method :add_item_match_params, :customer_request_match_draft, :buyback_line_match_draft, :load_match_context,
                   :add_item_cancel_path
  end
end
