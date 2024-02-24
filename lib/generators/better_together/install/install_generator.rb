# frozen_string_literal: true

module BetterTogether
  # Inital engine setup
  class InstallGenerator < Rails::Generators::Base
    desc 'Installs the Community Engine inside your app. Creates an initializer file at config/initializers/better_together.rb with the defaults'
    def create_initializer_file
      create_file(
        'config/initializers/better_together.rb',
        initializer_content
      )
    end

    private

    def initializer_content
      <<~CONTENT
        require 'better_together'

        BetterTogether.base_url = ENV.fetch(
          'BASE_URL',
          'http://localhost:3000'
        )
        BetterTogether.user_class = '::BetterTogether::User'

        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Migration::Current.include BetterTogether::MigrationHelpers
          ActiveRecord::ConnectionAdapters::TableDefinition.include BetterTogether::ColumnDefinitions
        end
      CONTENT
    end
  end
end
