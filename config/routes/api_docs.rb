# frozen_string_literal: true

# API Documentation (Swagger UI) — only mounted when rswag is available.
# Access is restricted to platform managers via Warden session check.
# Rswag::Api exposes swagger.yaml which contains internal schema details
# that should not be publicly browsable.
if defined?(Rswag::Ui::Engine) && defined?(Rswag::Api::Engine)
  constraints(lambda do |req|
    w = req.env['warden']
    w&.authenticated?(:user) && w.user(:user)&.person&.permitted_to?('manage_platform')
  end) do
    mount Rswag::Ui::Engine => 'docs'
    mount Rswag::Api::Engine => 'docs'
  end
end
