# frozen_string_literal: true

# lib/better_together/migration_helpers.rb

module BetterTogether
  # Reusable migration helpers to configure common table structures
  module MigrationHelpers
    # Invokes an engine rake task from a migration, in the engine's own dummy app
    # (tasks namespaced under app:) and in a host app that runs migrations from the gem.
    # The rake file is loaded only when the task is not already defined.
    # skip_when_empty: table(s) the task migrates; with no rows (a database built from
    # zero) the task is skipped, so it never loads models whose columns do not exist yet.
    def run_engine_rake_task(task_name, file: nil, skip_when_empty: nil)
      return if no_rows_to_migrate?(skip_when_empty)

      require 'rake'
      Rake::Task.define_task(:environment) unless Rake::Task.task_defined?('environment')
      load_engine_rake_file(file) if file && engine_rake_task_name(task_name).nil?

      name = engine_rake_task_name(task_name) || raise(ArgumentError, "Rake task #{task_name} is not defined")
      Rake::Task[name].reenable
      Rake::Task[name].invoke
    end

    def no_rows_to_migrate?(tables)
      tables.present? && Array(tables).none? { |table| table_has_rows?(table) }
    end

    def engine_rake_task_name(task_name)
      [task_name, "app:#{task_name}"].find { |name| Rake::Task.task_defined?(name) }
    end

    def table_has_rows?(table)
      table_exists?(table) && select_value("SELECT 1 FROM #{quote_table_name(table)} LIMIT 1").present?
    end

    def load_engine_rake_file(file)
      root = BetterTogether::Engine.root
      name = file.to_s.delete_prefix('tasks/')
      path = %w[lib/tasks lib/tasks/better_together].map { |dir| root.join(dir, name) }.find(&:exist?)
      raise ArgumentError, "Rake file #{file} not found in the engine" unless path

      load path
    end

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
    def create_bt_membership_table(table_name, member_type:, joinable_type:, id: :uuid, **options)
      # Handle the prefix for the table name
      member_table_name =
        options[:member_table_name].presence || "better_together_#{member_type.to_s.pluralize}"

      joinable_table_name =
        options[:joinable_table_name].presence || "better_together_#{joinable_type.to_s.pluralize}"

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

        yield(bt) if block_given?
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
