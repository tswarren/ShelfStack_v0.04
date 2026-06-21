# frozen_string_literal: true

module Seeds
  module Phase65Permissions
    PERMISSIONS = [
      {
        key: "items.external_lookup.access",
        group: "items",
        name: "Access External Lookup",
        description: "Access Add Item external ISBN lookup"
      },
      {
        key: "items.external_lookup.search",
        group: "items",
        name: "Search External Catalog",
        description: "Run external ISBN lookup"
      },
      {
        key: "items.external_lookup.import",
        group: "items",
        name: "Import External Catalog Item",
        description: "Create local catalog records from external candidates"
      },
      {
        key: "items.external_lookup.link_existing",
        group: "items",
        name: "Link External Candidate",
        description: "Link external candidate to existing catalog item"
      },
      {
        key: "items.external_lookup.update_existing",
        group: "items",
        name: "Update Existing From External",
        description: "Fill blank fields on existing catalog item from external candidate"
      },
      {
        key: "items.external_lookup.view_raw_payload",
        group: "items",
        name: "View External Raw Payload",
        description: "View raw provider response payloads"
      },
      {
        key: "items.external_lookup.configure",
        group: "items",
        name: "Configure External Lookup",
        description: "Configure external providers and run health checks"
      }
    ].freeze

    def self.seed!
      PERMISSIONS.each do |attrs|
        Permission.find_or_initialize_by(permission_key: attrs[:key]).tap do |permission|
          permission.permission_group = attrs[:group]
          permission.name = attrs[:name]
          permission.description = attrs[:description]
          permission.active = true
          permission.save!
        end
      end
    end
  end
end
