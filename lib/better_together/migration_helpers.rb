# frozen_string_literal: true

# lib/better_together/migration_helpers.rb

module BetterTogether
  # Reusable migration helpers to configure common table structures
  module MigrationHelpers
    # Creates a table with a standardized structure and naming convention.
    # @param table_name [Symbol, String] The base name of the table.
    # @param pk_index_prefix [String, nil] (Optional) Prefix for the primary key index.
    #                                      If not provided, the singularized table name is used.
    # @param prefix [String, nil] (Optional) Prefix for the table name, default is 'better_together'.
    #                              Can be set to nil or false to disable prefixing.
    # @param block [Block] Additional configuration block for table columns.
    def create_bt_table(table_name, prefix: 'better_together', id: :uuid)
      # Handle the prefix for the table name
      full_table_name = prefix ? "#{prefix.to_s.chomp('_')}_#{table_name}" : table_name.to_s

      create_table full_table_name, id: do |t|
        t.integer :lock_version, null: false, default: 0
        t.timestamps null: false

        yield(t) if block_given?
      end
    end

    # Creates a membership table with a standardized structure and naming convention.
    # @param table_name [Symbol, String] The base name of the table.
    # @param pk_index_prefix [String, nil] (Optional) Prefix for the primary key index.
    #                                      If not provided, the singularized table name is used.
    # @param prefix [String, nil] (Optional) Prefix for the table name, default is 'better_together'.
    #                              Can be set to nil or false to disable prefixing.
    # @param block [Block] Additional configuration block for table columns.
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def create_bt_membership_table(table_name, member_type:, joinable_type:, id: :uuid, **options)
      # Handle the prefix for the table name
      member_table_name =
        if options[:member_table_name].present?
          options[:member_table_name]
        else
          "better_together_#{member_type.to_s.pluralize}"
        end

      joinable_table_name =
        if options[:joinable_table_name].present?
          options[:joinable_table_name]
        else
          "better_together_#{joinable_type.to_s.pluralize}"
        end

      create_bt_table table_name, id: do |bt|
        # Reference to the better_together_people table for the member
        bt.bt_references :member,
                         null: false,
                         index: { name: "#{member_type}_#{joinable_type}_membership_by_member" },
                         target_table: member_table_name

        # Reference to the better_together_platforms table for the platform
        bt.bt_references :joinable,
                         null: false,
                         index: { name: "#{member_type}_#{joinable_type}_membership_by_joinable" },
                         target_table: joinable_table_name

        # Reference to the better_together_roles table for the role
        bt.bt_references :role,
                         null: false,
                         index: { name: "#{member_type}_#{joinable_type}_membership_by_role" },
                         target_table: :better_together_roles

        # Unique composite index
        bt.index %i[joinable_id member_id role_id],
                 unique: true,
                 name: "unique_#{member_type}_#{joinable_type}_membership_member_role"

        yield(t) if block_given?
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
  end
end
