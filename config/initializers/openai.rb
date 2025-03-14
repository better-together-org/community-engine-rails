# frozen_string_literal: true

if Rails.application.credentials.dig(:openai, :access_token)
  OpenAI.configure do |config|
    config.access_token = Rails.application.credentials.dig(:openai, :access_token),
                          config.log_errors = Rails.env.development?
  end
end
