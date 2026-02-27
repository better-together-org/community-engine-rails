# frozen_string_literal: true

# API Documentation (Swagger UI) — only mounted when rswag is available.
if defined?(Rswag::Ui::Engine) && defined?(Rswag::Api::Engine)
  mount Rswag::Ui::Engine => 'docs'
  mount Rswag::Api::Engine => 'docs'
end
