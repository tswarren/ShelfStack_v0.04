# frozen_string_literal: true

namespace :shelfstack do
  namespace :inventory_tracking do
    desc "Backfill products.default_inventory_tracking from product type (DRY_RUN=true to preview)"
    task backfill: :environment do
      dry_run = !%w[0 false no].include?(ENV.fetch("DRY_RUN", "false").to_s.downcase)
      updated = 0

      Product.find_each do |product|
        tracking = AddItem::InventoryTrackingMapper.for_product_type(product.product_type)
        next if product.default_inventory_tracking == tracking

        if dry_run
          puts "[dry-run] Product #{product.id} (#{product.sku}): default_inventory_tracking => #{tracking}"
        else
          product.update_column(:default_inventory_tracking, tracking)
        end
        updated += 1
      end

      puts dry_run ? "Would update #{updated} products." : "Updated #{updated} products."
      puts "inventory_tracking_override was not backfilled (intentional)."
    end

    desc "Report products whose active variants resolve to mixed inventory tracking"
    task report_mixed_products: :environment do
      mixed = 0

      Product.includes(:product_variants).find_each do |product|
        trackings = product.product_variants.active_records.map { |v| Inventory::TrackingResolver.resolve(v) }.uniq
        next if trackings.size <= 1

        mixed += 1
        puts "Product #{product.id} (#{product.sku}): #{trackings.join(', ')}"
      end

      puts "Mixed tracking products: #{mixed}"
    end

    desc "Report override/legacy behavior conflicts (e.g. non_inventory override + standard_physical behavior)"
    task report_tracking_conflicts: :environment do
      conflicts = 0

      ProductVariant.where.not(inventory_tracking_override: nil).find_each do |variant|
        override = variant.inventory_tracking_override
        behavior_tracking = Inventory::TrackingResolver.tracking_for_behavior(variant.inventory_behavior)
        next if override == behavior_tracking

        conflicts += 1
        puts "Variant #{variant.id} (#{variant.sku}): override=#{override}, behavior=#{variant.inventory_behavior} (#{behavior_tracking})"
      end

      puts "Tracking conflicts: #{conflicts}"
    end
  end
end
