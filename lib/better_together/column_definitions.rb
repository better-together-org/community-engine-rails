# frozen_string_literal: true

# lib/better_together/column_definitions.rb

module BetterTogether
  # Reusable helper for common column definitions
  module ColumnDefinitions # rubocop:todo Metrics/ModuleLength
    # Adds a 'community' reference for the primary community
    def bt_community(table_name = nil)
      table_name ||= name
      bt_references :community, target_table: :better_together_communities, null: false,
                                index: { name: "by_#{table_name.to_s.parameterize}_community" }
    end

    # Adds a 'creator' reference to a person
    def bt_creator(table_name = nil)
      table_name ||= name
      bt_references :creator, target_table: :better_together_people, null: true,
                              index: { name: "by_#{table_name.to_s.parameterize}_creator" }
    end

    # Adds a string column with emoji support and custom options.
    # @param name [Symbol, String] The name of the column.
    # @param options [Hash] Additional options (like limit, null, default).
    def bt_emoji_string(name, **options)
      options = { limit: 191, **options }
      options = with_emoji_defaults(**options)
      string(name, **options)
    end

    # Adds a text column with emoji support and custom options.
    # @param name [Symbol, String] The name of the column.
    # @param options [Hash] Additional options (like limit, null, default).
    def bt_emoji_text(name, **options)
      options = with_emoji_defaults(**options)
      text(name, **options)
    end

    # Adds a standard 'name' column with emoji support and default or custom indexing.
    # @param options [Hash] Additional options (like limit, null, default).
    def bt_emoji_name(**options)
      name_options = { index: { name: 'by_name' }, **options }
      bt_emoji_string(:name, **name_options)
    end

    # Adds a standard 'description' text column with emoji suppor
    # @param options [Hash] Additional options (like limit, null, default).
    def bt_emoji_description(**)
      bt_emoji_text(:description, **)
    end

    # Adds a host boolean column with a unique constraint that only allows one true value
    def bt_host
      boolean :host, default: false, null: false
      index :host, unique: true, where: 'host IS TRUE'
    end

    # Adds an 'identifier' string to identify (mostly) translated records
    def bt_identifier(limit: 100, null: false, index: { unique: true })
      string :identifier, null:, limit:, index: (index unless null)
    end

    def bt_label
      string :label, null: false
    end

    def bt_locale(table_name = nil)
      table_name ||= name
      string  :locale,
              limit: 5,
              null: false,
              index: {
                name: "by_#{table_name}_locale"
              },
              default: I18n.default_locale
    end

    # Adds location fields: iso_code with configurable length and format
    def bt_location(char_length: 2)
      string :iso_code, null: false, limit: char_length, index: { unique: true }
    end

    # Adds a 'position' boolean to prevent deletion of platform-critical records
    def bt_position
      integer :position, null: false
    end

    def bt_primary_flag(parent_key: nil)
      col_name = :primary_flag
      boolean col_name, null: false, default: false

      # Define the columns for the index
      columns = parent_key ? [parent_key, col_name] : [col_name]

      # Generate the index name
      index_name = index_name(name.sub('better_together', 'bt'), parent_key)

      # Build the WHERE clause with the column name
      where_clause = "#{col_name} IS TRUE"

      # Add the index with the properly quoted where clause
      index columns, unique: true, where: where_clause, name: index_name
    end

    # Helper method to generate a consistent index name
    def index_name(table_name, parent_key)
      if parent_key
        "index_#{table_name}_on_#{parent_key}_and_primary"
      else
        "index_#{table_name}_on_primary"
      end
    end

    # Adds a 'protected' boolean to prevent deletion of platform-critical records
    def bt_protected
      boolean :protected, null: false, default: false
    end

    # Adds 'privacy' column to give ability to manage record privacy
    def bt_privacy(table_name = nil, default: 'unlisted')
      table_name ||= name
      # Adding privacy column
      string :privacy, null: false, default:, limit: 50, index: { name: "by_#{table_name}_privacy" }
    end

    # Adds 'resource_type' column to give ability to manage record resource_type
    def bt_resource_type
      # Adding resource_type column
      string :resource_type, null: false
    end

    # Adds 'slug' column to give ability to set friendly_id using slug col
    def bt_slug
      # Adding slug column
      string :slug, null: false, index: { unique: true }
    end

    # Adds 'visible' column to give ability to set friendly_id using visible col
    def bt_visible
      # Adding visible column
      boolean :visible, null: false, default: true
    end

    # Adds a UUID/string reference column with an optional table prefix and default indexing,
    # and adds a foreign key if not polymorphic.
    # @param table_name [Symbol, String] The name of the referenced table.
    # @param table_prefix [Symbol, String, nil, false]
    # (Optional) Prefix for the table name, defaults to 'better_together'.
    # @param target_table [Symbol, String, nil] (Optional) Custom target table for the foreign key.
    # @param fk_column [Symbol, String, nil] (Optional) Custom foreign key column name.
    # @param args [Hash] Additional options for references.
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/CyclomaticComplexity
    def bt_references(table_name, table_prefix: 'better_together', target_table: nil, fk_column: nil, **args)
      full_table_name =
        if table_prefix
          "#{table_prefix.to_s.chomp('_')}_#{table_name.to_s.pluralize}"
        else
          table_name.to_s.pluralize
        end
      polymorphic = args[:polymorphic] || false
      foreign_key_provided = args[:foreign_key] || false
      fk_column ||= "#{table_name}_id"
      target_table ||= full_table_name

      # Set default options for foreign key reference
      options = respond_to?(:uuid) ? {} : { limit: 36 }
      options = { type: :uuid, **options }
      options = { **options, **args }

      # Add the foreign key reference column
      references table_name, **options

      # Add foreign key constraint unless polymorphic
      return if polymorphic || foreign_key_provided

      foreign_key target_table, column: fk_column, primary_key: :id
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    private

    # Merges provided options with default settings for emoji suppor
    # @param options [Hash] Custom options to be merged.
    # @return [Hash] Options merged with defaults for utf8mb4 collation.
    def with_emoji_defaults(**options)
      if ActiveRecord::Base.connection.adapter_name.downcase.starts_with?('mysql')
        { collation: 'utf8mb4', chatset: 'utf8mb4', **options }
      else
        { **options }
      end
    end
  end
end
