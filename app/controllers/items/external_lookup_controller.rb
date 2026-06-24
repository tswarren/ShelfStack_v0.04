# frozen_string_literal: true

module Items
  class ExternalLookupController < BaseController
    before_action :load_lookup_result, only: %i[preview import]
    before_action :load_match_context, only: %i[preview import]

    def lookup
      authorize!("items.external_lookup.search")
      return if performed?

      outcome = ExternalCatalog::LookupByIsbn.call(
        isbn: params.require(:isbn),
        actor: current_user
      )

      case outcome.status
      when :invalid
        redirect_to items_add_item_path(step: "identify"), alert: outcome.message
      when :local_match
        save_draft_for_local_match!(outcome.catalog_item)
        redirect_to items_add_item_path(step: "identify"),
                    notice: "Local catalog match found for ISBN #{outcome.normalized_isbn}."
      when :completed
        redirect_to items_external_lookup_result_path(outcome.lookup_result)
      else
        redirect_to items_add_item_path(step: "identify"), alert: outcome.message
      end
    end

    def preview
      authorize!("items.external_lookup.access")
      @preview = ExternalCatalog::ImportPreview.call(lookup_result: @lookup_result)
      @import_attributes = ExternalCatalog::MetadataMapper.catalog_attributes(candidate: @lookup_result)
      @formats = Format.active_records.order(:name)
      @can_view_raw_payload = Authorization.allowed?(
        user: current_user,
        permission_key: "items.external_lookup.view_raw_payload",
        store: current_store
      )
    end

    def import
      action_type = params.require(:action_type)
      authorize_import_action!(action_type)

      result = ExternalCatalog::ImportCandidate.call(
        lookup_result: @lookup_result,
        action_type: action_type,
        actor: current_user,
        format_id: params[:format_id],
        catalog_item_id: params[:catalog_item_id]
      )

      if result.status == :staged
        session[:add_item_draft] = (session[:add_item_draft] || {}).merge(
          "workflow" => "catalog_linked",
          "external_lookup_result_id" => @lookup_result.id,
          "external_lookup_format_id" => result.format&.id || params[:format_id]
        )
        redirect_to items_add_item_path(step: "item_details"),
                    notice: result.message
      elsif result.status == :applied && result.catalog_item.present?
        session[:add_item_draft] = (session[:add_item_draft] || {}).merge(
          "workflow" => "catalog_linked",
          "catalog_item_id" => result.catalog_item.id,
          "external_lookup_cover_image_url" => @lookup_result.image_url,
          "external_lookup_msrp_cents" => @lookup_result.msrp_cents
        ).compact
        redirect_to items_add_item_path(step: "item_details"),
                    notice: result.message
      elsif result.status == :skipped
        redirect_to items_add_item_path(step: "identify"), notice: result.message
      else
        redirect_to items_external_lookup_result_path(@lookup_result), alert: result.message
      end
    end

    private

    def load_lookup_result
      @lookup_result = ExternalLookupResult.find(params[:id])
    end

    def authorize_import_action!(action_type)
      permission = case action_type
      when "create_catalog_item" then "items.external_lookup.import"
      when "link_existing_catalog_item" then "items.external_lookup.link_existing"
      when "fill_blank_existing_catalog_item" then "items.external_lookup.update_existing"
      when "skip" then "items.external_lookup.access"
      else
                     redirect_to items_root_path, alert: "Invalid import action."
                     return
      end

      authorize!(permission)
    end

    def save_draft_for_local_match!(catalog_item)
      session[:add_item_draft] = (session[:add_item_draft] || {}).merge(
        "workflow" => "catalog_linked",
        "catalog_item_id" => catalog_item.id,
        "local_match_isbn" => params[:isbn]
      )
    end

    def load_match_context
      draft = session[:add_item_draft] || {}
      if draft["return_to"] == Buybacks::LineMatchContext::RETURN_TO
        @match_context = Buybacks::LineMatchContext.from_draft(draft, store: current_store)
      elsif draft["return_to"] == Customers::RequestMatchContext::RETURN_TO
        @match_context = Customers::RequestMatchContext.new(
          return_to: draft["return_to"],
          customer_request_id: draft["customer_request_id"],
          line_id: draft["customer_request_line_id"],
          store: current_store
        )
      end
    end
  end
end
