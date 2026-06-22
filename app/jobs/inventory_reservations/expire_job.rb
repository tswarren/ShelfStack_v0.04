# frozen_string_literal: true

module InventoryReservations
  class ExpireJob < ApplicationJob
    queue_as :default

    def perform
      actor = User.find_by!(username: ShelfStack::SYSTEM_USERNAME)
      InventoryReservations::Expire.call!(actor: actor)
    end
  end
end
