# frozen_string_literal: true

module SystemTestDatabase
  module_function

  def reset!
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata]

    return if tables.empty?

    connection.disable_referential_integrity do
      tables.each do |table|
        connection.execute("TRUNCATE TABLE #{connection.quote_table_name(table)} RESTART IDENTITY CASCADE")
      end
    end
  end
end
