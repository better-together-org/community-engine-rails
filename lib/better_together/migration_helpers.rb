# frozen_string_literal: true

# lib/better_together/migration_helpers.rb

module BetterTogether
  module MigrationHelpers
    # Creates a table with a standardized structure and naming convention.
    # @param table_name [Symbol, String] The base name of the table.
    # @param pk_index_prefix [String, nil] (Optional) Prefix for the primary key index.
    #                                      If not provided, the singularized table name is used.
    # @param prefix [String, nil] (Optional) Prefix for the table name, default is 'better_together'.
    #                              Can be set to nil or false to disable prefixing.
    # @param block [Block] Additional configuration block for table columns.
    def create_bt_table(table_name, pk_index_prefix: nil, prefix: 'better_together')
      # Handle the prefix for the table name
      full_table_name = prefix ? "#{prefix.to_s.chomp('_')}_#{table_name}" : table_name.to_s

      # Automatic generation of pk_index_prefix from the table name if not provided
      pk_index_prefix ||= table_name.to_s.singularize

      pk_index_name = "#{pk_index_prefix}_by_bt_id"

      pk_options = { primary_key: true, null: false, index: { name: pk_index_name, unique: true } }

      create_table full_table_name, id: false do |t|
        pk_options = { limit: 36, **pk_options } unless t.respond_to?(:uuid)
        pk_method = t.respond_to?(:uuid) ? :uuid : :string
        t.send(pk_method, :bt_id, **pk_options)

        t.integer :lock_version, null: false, default: 0
        t.timestamps null: false

        yield(t) if block_given?
      end
    end
  end
end
