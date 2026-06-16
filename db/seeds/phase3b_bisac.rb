# frozen_string_literal: true

module Seeds
  module Phase3bBisac
    module_function

    def import!
      return if ENV["SKIP_BISAC_SEED"].present?
      return if Rails.env.test? && ENV["SEED_BISAC"].blank?

      result = Bisac::CategoryNodeImporter.call
      puts "  BISAC: #{result.created} created, #{result.updated} updated (#{result.total} total)"
      result
    end
  end
end
