module BetterTogether
  # Inital engine setup
  class InstallGenerator < Rails::Generators::Base
    desc "Installs the Community Engine inside your app. Creates an initializer file at config/initializers/better_together.rb with the defaults"
    def create_initializer_file
      create_file(
        'config/initializers/better_together.rb',
        initializer_content
      )
    end

    private

    def initializer_content
      <<-CONTENT
require 'better_together'

BetterTogether.user_class = 'BetterTogether::User'
BetterTogether.default_user_confirm_success_url = ENV.fetch(
  'APP_HOST',
  'http://localhost:3000'
)
BetterTogether.default_user_new_password_url = ENV.fetch(
  'APP_HOST',
  'http://localhost:3000'
) + '/bt/api/auth/password/new'
      CONTENT
    end
  end
end
