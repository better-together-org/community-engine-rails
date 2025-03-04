# frozen_string_literal: true

# Ensures that all tables with the privacy column default to private
# Replaces existing 'unlisted' values with 'private'
class SetPrivacyDefaultPrivate < ActiveRecord::Migration[7.1]
  def up
    ActiveRecord::Base.connection.tables.each do |table|
      next unless column_exists?(table, :privacy)

      # Replace existing 'unlisted' values with 'private'
      execute "UPDATE #{table} SET privacy = 'private' WHERE privacy = 'unlisted'"

      privacy_column = ActiveRecord::Base.connection.columns(table).find { |col| col.name == 'privacy' }
      next unless privacy_column
      next if privacy_column.default == 'private'

      say "Changing default privacy for table #{table} from #{privacy_column.default.inspect} to 'private'"
      change_column_default table, :privacy, 'private'
    end
  end

  def down
    # No reversal defined as reverting the default value change and data update is not supported.
  end
end
