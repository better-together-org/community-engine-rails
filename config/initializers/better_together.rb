# frozen_string_literal: true

require 'better_together'

BetterTogether.base_url = ENV.fetch(
  'BASE_URL',
  'http://localhost:3000'
)
BetterTogether.user_class = '::BetterTogether::User'

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration::Current.include BetterTogether::MigrationHelpers
  ActiveRecord::ConnectionAdapters::Table.include BetterTogether::ColumnDefinitions
  ActiveRecord::ConnectionAdapters::TableDefinition.include BetterTogether::ColumnDefinitions
end
