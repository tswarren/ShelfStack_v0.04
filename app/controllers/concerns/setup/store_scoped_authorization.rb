# frozen_string_literal: true

module Setup
  module StoreScopedAuthorization
    extend ActiveSupport::Concern

    private

    def authorize_store_access!(store, permission_key:)
      return if Authorization.allowed?(user: current_user, permission_key: permission_key, store: store)

      redirect_to setup_root_path, alert: "You are not authorized to manage tax setup for this store."
    end

    def accessible_stores_for(permission_key)
      Authorization.accessible_stores(user: current_user, permission_key: permission_key)
    end
  end
end
