require 'better_together'

BetterTogether.user_class = 'BetterTogether::User'
BetterTogether.default_user_confirmation_url = ENV.fetch(
  'APP_HOST',
  'http://localhost:3000'
) + '/bt/api/auth/confirmation'
BetterTogether.default_user_new_password_url = ENV.fetch(
  'APP_HOST',
  'http://localhost:3000'
) + '/bt/api/auth/password/new'

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration::Current.include BetterTogether::MigrationHelpers
  ActiveRecord::ConnectionAdapters::TableDefinition.include BetterTogether::ColumnDefinitions
end

