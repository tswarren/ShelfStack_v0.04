# frozen_string_literal: true

module Pos
  class RootCommandHandler
    Result = Data.define(:status, :redirect_path, :json, :alert)

    def self.call(store:, workstation:, cashier_user:, register_session:, user_session:, input:, product_variant_id: nil)
      new(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session,
        user_session: user_session,
        input: input,
        product_variant_id: product_variant_id
      ).call
    end

    def initialize(store:, workstation:, cashier_user:, register_session:, user_session:, input:, product_variant_id: nil)
      @store = store
      @workstation = workstation
      @cashier_user = cashier_user
      @register_session = register_session
      @user_session = user_session
      @input = input
      @product_variant_id = product_variant_id
    end

    def call
      if product_variant_id.present?
        return add_variant_and_redirect { ProductVariant.find(product_variant_id) }
      end

      route = RootCommandRouter.call(
        store: store,
        input: input,
        user: cashier_user,
        register_session: register_session
      )

      case route.action
      when :add_variant
        add_variant_and_redirect { ProductVariant.find(route.payload[:variant_id]) }
      when :open_ring_offer, :gift_card_sale_offer
        carry_forward_and_redirect(route)
      when :return_drawer_offer, :pickup_drawer_offer
        drawer_offer_result(route)
      when :balance_redirect
        Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_stored_value_balance_path, json: nil, alert: nil)
      when :help, :message, :empty, :disabled_command, :variant_lookup
        Result.new(
          status: :json,
          redirect_path: nil,
          json: json_route(route),
          alert: nil
        )
      else
        Result.new(
          status: :json,
          redirect_path: nil,
          json: {
            action: "message",
            payload: {},
            message: CommandParser::FAILED_LOOKUP_MESSAGE
          },
          alert: nil
        )
      end
    end

    private

    attr_reader :store, :workstation, :cashier_user, :register_session, :user_session, :input, :product_variant_id

    def drawer_offer_result(route)
      if route.action == :return_drawer_offer && return_blocked_for_active_draft?
        return json_message_result(CommandRouteBuilder::RETURN_BLOCKED_TENDERS_MESSAGE)
      end

      Result.new(
        status: :json,
        redirect_path: nil,
        json: json_route(route),
        alert: nil
      )
    end

    def return_blocked_for_active_draft?
      return false if register_session.blank?

      resolution = ActiveDraftResolver.call(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session
      )
      return false unless resolution.status == :found

      return_blocked_for_transaction?(resolution.draft)
    end

    def carry_forward_and_redirect(route)
      with_draft_redirect do |transaction|
        CommandCarryForward.edit_path(
          transaction: transaction,
          carry_forward: CommandCarryForward.carry_forward_for(route.action),
          amount_cents: route.payload[:amount_cents],
          receipt_number: route.payload[:receipt_number],
          mode: CommandCarryForward.mode_for(route.action)
        )
      end
    end

    def return_blocked_for_transaction?(transaction)
      transaction.pos_tenders.settlement_rows.exists?
    end

    def json_message_result(message)
      Result.new(
        status: :json,
        redirect_path: nil,
        json: { action: "message", payload: {}, message: message },
        alert: nil
      )
    end

    def add_variant_and_redirect
      variant = yield

      with_draft_redirect do |transaction|
        AddVariantLine.call!(transaction: transaction, variant: variant)
        Rails.application.routes.url_helpers.edit_pos_transaction_path(transaction, mode: "sale")
      end
    rescue ActiveRecord::RecordNotFound
      item_not_found_result
    rescue AddVariantLine::Error, ActiveRecord::RecordInvalid => e
      add_line_failed_result(e.message)
    end

    def with_draft_redirect
      draft_result = DraftCreator.call(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session,
        user_session: user_session
      )

      case draft_result.status
      when :legacy_found
        Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "An older draft needs review before adding items.")
      when :conflict
        Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "Multiple active drafts exist. Resolve the conflict before adding items.")
      when :missing_register_session, :invalid_register_session
        Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "Open the register before adding items.")
      when :created, :resumed
        path = yield(draft_result.transaction)
        Result.new(status: :redirect, redirect_path: path, json: nil, alert: nil)
      else
        Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "Unable to start transaction.")
      end
    end

    def item_not_found_result
      Result.new(
        status: :json,
        redirect_path: nil,
        json: { action: "message", payload: {}, message: "Item could not be found." },
        alert: nil
      )
    end

    def add_line_failed_result(message)
      Result.new(
        status: :json,
        redirect_path: nil,
        json: { action: "message", payload: {}, message: message.presence || "Unable to add item." },
        alert: nil
      )
    end

    def json_route(route)
      payload = route.payload.dup
      if payload[:variants]
        lookup_result = LineLookup::Result.new(
          status: payload[:status] || :found,
          variants: payload[:variants],
          message: route.message
        )
        presented = LineLookupPresenter.as_json(lookup_result, store: store)
        payload = payload.merge(
          status: lookup_result.status.to_s,
          variants: presented[:variants]
        )
      end

      {
        action: route.action.to_s,
        payload: payload,
        message: route.message
      }
    end
  end
end
