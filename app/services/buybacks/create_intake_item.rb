# frozen_string_literal: true

module Buybacks
  class CreateIntakeItem
    class Error < StandardError; end

    Result = Data.define(:product, :product_variant, :created_new_product)

    def self.call!(session:, actor:, line:, title:, sub_department:, condition: nil, identifier: nil, list_price_cents: nil)
      new(session:, actor:, line:, title:, sub_department:, condition:, identifier:, list_price_cents:).call!
    end

    def initialize(session:, actor:, line:, title:, sub_department:, condition: nil, identifier: nil, list_price_cents: nil)
      @session = session
      @actor = actor
      @line = line
      @title = title.to_s.strip
      @sub_department = sub_department
      @condition = condition || default_condition
      @identifier = identifier.to_s.strip.presence
      @list_price_cents = list_price_cents
    end

    def call!
      raise Error, "Session is not editable." unless session.editable?
      raise Error, "Title is required." if title.blank?
      raise Error, "Subdepartment is required." if sub_department.blank?
      raise Error, "Subdepartment does not allow buyback." unless sub_department.buyback_allowed?
      raise Error, "Condition is not buyback-eligible." unless condition.buyback_eligible?

      existing_product = find_existing_product
      if existing_product.present?
        return link_existing_product!(existing_product)
      end

      create_full_intake!
    end

    private

    attr_reader :session, :actor, :line, :title, :sub_department, :condition, :identifier, :list_price_cents

    def find_existing_product
      if identifier.present?
        normalized = normalize_identifier(identifier)
        product = Product.find_by(sku: normalized)
        return product if product.present?

        bridge_product = Items::ProductIdentifierLookup.find_products_by_query(normalized).order(:id).first
        return bridge_product if bridge_product.present?
      end

      resolve = ResolveItem.call(store: session.store, identifier: identifier, title: title)
      resolve.product
    end

    def link_existing_product!(product)
      Product.transaction do
        line.update!(
          product: product,
          product_condition: condition,
          sub_department: sub_department,
          title_snapshot: product.display_title,
          list_price_cents: list_price_cents || product.list_price_cents,
          status: "resolved"
        )
        PricingFieldSync.refresh!(line: line.reload)
      end

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.intake.linked",
        auditable: product,
        source: session,
        details: { "product_id" => product.id }
      )

      Result.new(product:, product_variant: nil, created_new_product: false)
    end

    def create_full_intake!
      format = Format.active_records.find_by(format_key: "hardcover") ||
        Format.active_records.order(:name).first
      raise Error, "No active format available for intake." if format.blank?

      product = nil

      Product.transaction do
        product = Product.new(
          catalog_item_type: "book",
          title: title,
          publication_status: "active",
          format: format,
          source: "buyback_intake",
          needs_review: true,
          created_from_buyback_session: session,
          active: true,
          product_type: "physical",
          variation_type: "conditional",
          list_price_cents: list_price_cents.to_i,
          default_sub_department: sub_department
        )

        assign_transitional_sku!(product)
        product.save!

        line.update!(
          product: product,
          created_product: product,
          product_condition: condition,
          sub_department: sub_department,
          title_snapshot: title,
          list_price_cents: list_price_cents.to_i,
          status: "resolved"
        )
        PricingFieldSync.refresh!(line: line.reload)
      end

      AuditEvents.record!(actor: actor, event_name: "buyback.intake.created", auditable: product, source: session)
      Result.new(product:, product_variant: nil, created_new_product: true)
    end

    def assign_transitional_sku!(product)
      if identifier.present?
        AddItem::TransitionalSkuAssigner.assign!(
          product: product,
          identifier_type: infer_identifier_type(identifier),
          identifier_value: identifier,
          actor: actor
        )
      else
        AddItem::TransitionalSkuAssigner.assign!(product: product, actor: actor)
      end
    end

    def default_condition
      ProductCondition.buyback_eligible.find_by(buyback_default: true) ||
        ProductCondition.buyback_eligible.order(:buyback_sort_order, :sort_order).first
    end

    def normalize_identifier(value)
      value.upcase.gsub(/[^0-9X]/i, "")
    end

    def infer_identifier_type(value)
      normalized = normalize_identifier(value)
      normalized.length == 13 ? "isbn13" : "isbn10"
    end
  end
end
