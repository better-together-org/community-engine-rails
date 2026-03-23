# frozen_string_literal: true

# rswag-api is a development/test dependency — skip gracefully in production host apps.
return unless defined?(Rswag::Api)

Rswag::Api.configure do |c|
  c.openapi_root = BetterTogether::Engine.root.join('swagger').to_s
end
