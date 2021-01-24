require 'better_together'

BetterTogether.user_class = 'BetterTogether::User'
BetterTogether.default_user_confirm_success_url = ENV.fetch(
  'APP_HOST',
  'http://localhost:3000'
)
