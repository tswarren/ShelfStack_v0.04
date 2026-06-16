# frozen_string_literal: true

module Items
  class IngramImportController < BaseController
    PREVIEW_LIMIT = 20
    ALLOWED_EXTENSIONS = %w[.xls .xlsx].freeze
    CACHE_EXPIRY = 2.hours

    before_action :authorize_import!
    before_action :load_collections, only: %i[show create preview]

    def show
      load_preview_from_cache
      load_result_from_cache
    end

    def preview
      file = params.require(:import_file)
      validate_upload!(file)
      store_uploaded_file!(file)

      rows = IngramCatalogImport::SpreadsheetParser.call(path: session[:ingram_import_path])
      store_preview_cache!(
        rows: rows,
        sub_department_id: params[:sub_department_id],
        store_category_id: params[:store_category_id],
        display_location_id: params[:display_location_id]
      )

      redirect_to items_ingram_import_path, notice: "Parsed #{rows.size} rows. Review the preview, then run import."
    rescue IngramCatalogImport::SpreadsheetParser::ParseError => e
      redirect_to items_ingram_import_path, alert: e.message
    end

    def create
      path = session[:ingram_import_path]
      if path.blank? || !File.exist?(path)
        redirect_to items_ingram_import_path, alert: "Upload and preview a file before running import."
        return
      end

      preview_data = preview_cache_data
      sub_department = SubDepartment.active_records.find_by(
        id: params[:sub_department_id].presence || preview_data&.dig(:sub_department_id)
      )
      if sub_department.blank?
        redirect_to items_ingram_import_path, alert: "Default subdepartment is required."
        return
      end

      display_location_id = params[:display_location_id].presence || preview_data&.dig(:display_location_id)
      display_location = DisplayLocation.active_records.find_by(id: display_location_id)
      store_category = resolve_store_category
      options = IngramCatalogImport::ImportOptions.new(
        default_sub_department: sub_department,
        default_store_category: store_category,
        default_display_location: display_location
      )

      result = IngramCatalogImport::Runner.call(path: path, actor: current_user, options: options)
      store_result_cache!(result)
      cleanup_upload!

      redirect_to items_ingram_import_path,
                  notice: "Import complete. #{result.count(:variant_created)} variants created, #{result.count(:variant_matched)} matched existing."
    end

    private

    def authorize_import!
      authorize!("items.ingram_import.run")
    end

    def load_collections
      @sub_departments = SubDepartment.active_records.order(:name)
      @display_locations = DisplayLocation.active_for_tree_select
      @store_category_scheme = CategoryScheme.active_records.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      @store_category_nodes = if @store_category_scheme
                                CategoryNode.active_for_tree_select(@store_category_scheme)
                              else
                                CategoryNode.none
                              end
    end

    def resolve_store_category
      node_id = params[:store_category_id].presence || preview_cache_data&.dig(:store_category_id)
      @store_category_nodes.find_by(id: node_id)
    end

    def validate_upload!(file)
      extension = File.extname(file.original_filename.to_s).downcase
      unless ALLOWED_EXTENSIONS.include?(extension)
        raise IngramCatalogImport::SpreadsheetParser::ParseError, "Upload an .xls or .xlsx file."
      end
    end

    def store_uploaded_file!(file)
      cleanup_upload!

      dir = Rails.root.join("tmp/ingram_imports")
      FileUtils.mkdir_p(dir)
      token = SecureRandom.hex(16)
      extension = File.extname(file.original_filename.to_s).downcase.presence || ".xls"
      path = dir.join("#{current_user.id}_#{token}#{extension}")
      File.binwrite(path, file.read)

      session[:ingram_import_path] = path.to_s
    end

    def cleanup_upload!
      path = session[:ingram_import_path]
      File.delete(path) if path.present? && File.exist?(path)
      session.delete(:ingram_import_path)
      clear_preview_cache!
    end

    def store_preview_cache!(rows:, sub_department_id:, store_category_id:, display_location_id:)
      clear_preview_cache!
      key = cache_key("preview")
      Rails.cache.write(
        key,
        {
          rows: rows.first(PREVIEW_LIMIT).map(&:to_preview_hash),
          row_count: rows.size,
          sub_department_id: sub_department_id,
          store_category_id: store_category_id,
          display_location_id: display_location_id
        },
        expires_in: CACHE_EXPIRY
      )
      session[:ingram_import_preview_key] = key
    end

    def load_preview_from_cache
      data = preview_cache_data
      return if data.blank?

      @preview_rows = data[:rows]
      @row_count = data[:row_count]
      @selected_sub_department_id = data[:sub_department_id]
      @selected_store_category_id = data[:store_category_id]
      @selected_display_location_id = data[:display_location_id]
    end

    def preview_cache_data
      key = session[:ingram_import_preview_key]
      return if key.blank?

      Rails.cache.read(key)
    end

    def clear_preview_cache!
      key = session[:ingram_import_preview_key]
      Rails.cache.delete(key) if key.present?
      session.delete(:ingram_import_preview_key)
    end

    def store_result_cache!(result)
      key = cache_key("result")
      Rails.cache.write(key, serialize_result(result), expires_in: CACHE_EXPIRY)
      session[:ingram_import_result_key] = key
    end

    def load_result_from_cache
      key = session.delete(:ingram_import_result_key)
      return if key.blank?

      @import_result = Rails.cache.read(key)
      Rails.cache.delete(key)
    end

    def cache_key(kind)
      "ingram_import:#{kind}:#{current_user.id}:#{SecureRandom.hex(8)}"
    end

    def serialize_result(result)
      {
        summary: result.summary,
        outcomes: result.outcomes.map do |outcome|
          {
            row_number: outcome.row_number,
            identifier: outcome.identifier,
            title: outcome.title,
            status: outcome.status.to_s,
            message: outcome.message,
            catalog_item_id: outcome.catalog_item_id,
            product_id: outcome.product_id,
            product_variant_id: outcome.product_variant_id
          }
        end
      }
    end
  end
end
