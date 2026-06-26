# frozen_string_literal: true

module Items
  class ItemAttentionPresenter
    AttentionItem = Data.define(:message, :link_path, :link_label)

    def self.for(item:, store:, user:, operations: nil)
      new(item:, store:, user:, operations:).items
    end

    def initialize(item:, store:, user:, operations: nil)
      @item = item
      @store = store
      @user = user
      @operations = operations || ItemOperationsPresenter.new(item:, store:, user:)
    end

    def items
      list = []
      list.concat(open_tbo_items)
      list.concat(ordering_warning_items)
      list.concat(setup_items)
      list.concat(returnability_items)
      list.concat(identifier_items)
      list
    end

    private

    attr_reader :item, :store, :user, :operations

    def open_tbo_items
      total_tbo = operations.variant_rows.sum(&:open_tbo)
      return [] unless total_tbo.positive?

      [
        AttentionItem.new(
          message: "#{total_tbo} open TBO #{'unit'.pluralize(total_tbo)} are not yet fully on purchase orders.",
          link_path: item.tab_path("operations"),
          link_label: "View operations"
        )
      ]
    end

    def ordering_warning_items
      operations.variant_rows.flat_map do |row|
        Items::OperationalWarningBuilder.call(product_variant: row.variant, store: store).filter_map do |warning|
          next if warning.severity == :info

          AttentionItem.new(
            message: "#{row.variant.sku}: #{warning.message}",
            link_path: warning.action_path,
            link_label: warning.action_label || "Review"
          )
        end
      end.uniq { |item| item.message }
    end

    def setup_items
      items = []
      item.variants.each do |variant|
        if variant.selling_price_cents.to_i.zero?
          items << AttentionItem.new(
            message: "#{variant.sku} is missing a selling price.",
            link_path: edit_items_product_variant_path(variant, return_to: "item"),
            link_label: "Edit SKU"
          )
        end
        if variant.sub_department_id.blank?
          items << AttentionItem.new(
            message: "#{variant.sku} is missing a subdepartment.",
            link_path: edit_items_product_variant_path(variant, return_to: "item"),
            link_label: "Edit SKU"
          )
        end
        if variant.display_location_id.blank? && item.product&.default_display_location_id.blank?
          items << AttentionItem.new(
            message: "#{variant.sku} has no display location.",
            link_path: item.tab_path("item_setup"),
            link_label: "Item setup"
          )
        end
      end
      items
    end

    def returnability_items
      operations.variant_rows.filter_map do |row|
        next if row.returnability_status.blank? || row.returnability_status == "returnable"

        AttentionItem.new(
          message: "#{row.variant.sku} has #{row.returnability_status.humanize.downcase} returnability.",
          link_path: Items::VendorSourcingPath.for(row.variant),
          link_label: "Review sourcing"
        )
      end
    end

    def identifier_items
      return [] unless item.full_statuses.include?("invalid_identifier_warning")

      [
        AttentionItem.new(
          message: "Primary or secondary identifier needs review.",
          link_path: item.tab_path("item_setup"),
          link_label: "Review identifiers"
        )
      ]
    end

    include Rails.application.routes.url_helpers
  end
end
