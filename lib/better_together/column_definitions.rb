# lib/better_together/column_definitions.rb

module BetterTogether
  module ColumnDefinitions
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

    # Adds a standard 'description' text column with emoji support.
    # @param options [Hash] Additional options (like limit, null, default).
    def bt_emoji_description(**options)
      bt_emoji_text(:description, **options)
    end

    # Adds a UUID/string reference column with an optional table prefix and default indexing.
    # The reference points to the bt_id primary key of the target table.
    # @param table_name [Symbol, String] The name of the referenced table.
    # @param table_prefix [Symbol, String, nil, false] (Optional) Prefix for the table name, defaults to 'better_together'.
    # @param args [Hash] Additional options for t.references.
    def bt_references(table_name, table_prefix: 'better_together', **args)
      proc do |t|
        # Define the full table name with the optional prefix
        full_table_name = table_prefix ? "#{table_prefix.to_s.chomp('_')}_#{table_name}" : table_name.to_s

        # Default foreign key type to :uuid if supported, else :string
        fk_type = t.respond_to?(:uuid) ? :uuid : :string

        # Set default options for foreign key reference
        options = {
          type: fk_type,
          limit: 36,
          primary_key: 'bt_id',
          **args
        }

        # Handle index option
        options[:index] = { name: "by_#{table_name}" } unless args.key?(:index)

        # Add the foreign key reference column
        t.references full_table_name, **options
      end
    end

    private

    # Merges provided options with default settings for emoji support.
    # @param options [Hash] Custom options to be merged.
    # @return [Hash] Options merged with defaults for utf8mb4 collation.
    def with_emoji_defaults(**options)
      { collation: 'utf8mb4', **options }
    end
  end
end
