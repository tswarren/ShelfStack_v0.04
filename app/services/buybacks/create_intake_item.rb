# frozen_string_literal: true

module Buybacks
  class CreateIntakeItem
    class Error < StandardError; end

    Result = Data.define(:catalog_item, :product, :product_variant, :created_new_catalog)

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

      existing_catalog = find_existing_catalog_item
      if existing_catalog.present?
        return link_existing_catalog!(existing_catalog)
      end

      create_full_intake!
    end

    private

    attr_reader :session, :actor, :line, :title, :sub_department, :condition, :identifier, :list_price_cents

    def find_existing_catalog_item
      if identifier.present?
        ident = CatalogItemIdentifier.active_records.find_by(normalized_identifier: normalize_identifier(identifier))
        return ident.catalog_item if ident.present?
      end

      resolve = ResolveItem.call(store: session.store, identifier: identifier, title: title)
      resolve.catalog_item
    end

    def link_existing_catalog!(catalog_item)
      product = catalog_item.products.active_records.first
      product = create_intake_product!(catalog_item) if product.blank?

      CatalogItem.transaction do
        line.update!(
          catalog_item: catalog_item,
          product: product,
          product_condition: condition,
          sub_department: sub_department,
          title_snapshot: catalog_item.title,
          list_price_cents: list_price_cents || product.list_price_cents,
          status: "resolved"
        )
        PricingFieldSync.refresh!(line: line.reload)
      end

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.intake.linked",
        auditable: catalog_item,
        source: session,
        details: { "catalog_item_id" => catalog_item.id, "product_id" => product.id }
      )

      Result.new(catalog_item:, product:, product_variant: nil, created_new_catalog: false)
    end

    def create_full_intake!
      format = Format.active_records.find_by(format_key: "hardcover") ||
        Format.active_records.order(:name).first
      raise Error, "No active format available for intake." if format.blank?

      catalog_item = nil
      product = nil

      CatalogItem.transaction do
        catalog_item = CatalogItem.create!(
          catalog_item_type: "book",
          title: title,
          publication_status: "active",
          format: format,
          source: "buyback_intake",
          needs_review: true,
          created_from_buyback_session: session,
          active: true
        )

        if identifier.present?
          CatalogIdentifierService.add_identifier!(
            catalog_item: catalog_item,
            identifier_type: infer_identifier_type(identifier),
            value: identifier,
            primary: true,
            actor: actor,
            source: "buyback_intake"
          )
        else
          CatalogIdentifierService.generate_local!(catalog_item: catalog_item, actor: actor)
        end

        product = Product.create!(
          catalog_item: catalog_item,
          product_type: "physical",
          variation_type: "conditional",
          list_price_cents: list_price_cents.to_i,
          default_sub_department: sub_department,
          source: "buyback_intake",
          needs_review: true,
          created_from_buyback_session: session,
          active: true
        )

        line.update!(
          catalog_item: catalog_item,
          product: product,
          created_catalog_item: catalog_item,
          created_product: product,
          product_condition: condition,
          sub_department: sub_department,
          title_snapshot: title,
          list_price_cents: list_price_cents.to_i,
          status: "resolved"
        )
        PricingFieldSync.refresh!(line: line.reload)
      end

      AuditEvents.record!(actor: actor, event_name: "buyback.intake.created", auditable: catalog_item, source: session)
      Result.new(catalog_item:, product:, product_variant: nil, created_new_catalog: true)
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

    def create_intake_product!(catalog_item)
      Product.create!(
        catalog_item: catalog_item,
        product_type: "physical",
        variation_type: "conditional",
        list_price_cents: list_price_cents.to_i,
        default_sub_department: sub_department,
        source: "buyback_intake",
        needs_review: true,
        created_from_buyback_session: session,
        active: true
      )
    end
  end
end
