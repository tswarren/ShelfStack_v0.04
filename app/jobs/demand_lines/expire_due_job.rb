# frozen_string_literal: true

module DemandLines
  class ExpireDueJob < ApplicationJob
    queue_as :default

    def perform(store_id: nil)
      store = store_id.present? ? Store.find(store_id) : nil
      system_user = User.find_by!(username: ShelfStack::SYSTEM_USERNAME)
      DemandLines::ExpireDue.call!(store: store, actor: system_user)
    end
  end
end
