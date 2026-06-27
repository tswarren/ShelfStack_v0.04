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
        return add_variant_and_redirect(ProductVariant.find(product_variant_id))
      end

      route = RootCommandRouter.call(store: store, input: input)

      case route.action
      when :add_variant
        add_variant_and_redirect(ProductVariant.find(route.payload[:variant_id]))
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
            message: RootCommandRouter::FAILED_LOOKUP_MESSAGE
          },
          alert: nil
        )
      end
    end

    private

    attr_reader :store, :workstation, :cashier_user, :register_session, :user_session, :input, :product_variant_id

    def add_variant_and_redirect(variant)
      draft_result = DraftCreator.call(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session,
        user_session: user_session
      )

      case draft_result.status
      when :legacy_found
        return Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "An older draft needs review before adding items.")
      when :conflict
        return Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "Multiple active drafts exist. Resolve the conflict before adding items.")
      when :missing_register_session, :invalid_register_session
        return Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "Open the register before adding items.")
      when :created, :resumed
        AddVariantLine.call!(transaction: draft_result.transaction, variant: variant)
        path = Rails.application.routes.url_helpers.edit_pos_transaction_path(draft_result.transaction, mode: "sale")
        Result.new(status: :redirect, redirect_path: path, json: nil, alert: nil)
      else
        Result.new(status: :redirect, redirect_path: Rails.application.routes.url_helpers.pos_root_path, json: nil, alert: "Unable to start transaction.")
      end
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
