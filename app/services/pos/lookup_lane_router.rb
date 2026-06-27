# frozen_string_literal: true

module Pos
  class LookupLaneRouter
    Route = Data.define(:action, :payload, :message)

    def self.call(store:, query:, context:)
      new(store: store, query: query, context: context).call
    end

    def initialize(store:, query:, context:)
      @store = store
      @query = query.to_s.strip
      @context = context.to_sym
    end

    def call
      lookup = LineLookup.call(store: store, query: query)

      if lookup.variants.one?
        return single_variant_route(lookup.variants.first)
      end

      if lookup.variants.many?
        return Route.new(
          action: :variant_lookup,
          payload: { status: lookup.status, variants: lookup.variants },
          message: lookup.message
        )
      end

      Route.new(action: :message, payload: {}, message: CommandParser::FAILED_LOOKUP_MESSAGE)
    end

    private

    attr_reader :store, :query, :context

    def single_variant_route(variant)
      if context == :root
        Route.new(action: :add_variant, payload: { variant_id: variant.id }, message: nil)
      else
        Route.new(
          action: :variant_lookup,
          payload: { status: :found, variants: [ variant ] },
          message: nil
        )
      end
    end
  end
end
