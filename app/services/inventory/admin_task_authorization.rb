# frozen_string_literal: true

module Inventory
  module AdminTaskAuthorization
    class AuthorizationError < StandardError; end

    def self.authorize!(username:)
      raise AuthorizationError, "USERNAME environment variable is required" if username.blank?

      user = User.active_records.find_by(username: username)
      raise AuthorizationError, "User not found: #{username}" unless user

      unless Authorization.globally_allowed?(user: user, permission_key: "inventory.admin.rebuild_balances")
        raise AuthorizationError, "User #{username} lacks global inventory.admin.rebuild_balances permission"
      end

      user
    end
  end
end
