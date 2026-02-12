# frozen_string_literal: true

module ApiAuthHelpers
  def api_sign_in_and_get_token(user, password: 'SecureTest123!@#')
    post '/api/auth/sign-in',
         params: {
           user: {
             email: user.email,
             password: password
           }
         },
         as: :json

    token = response.headers['Authorization']&.delete_prefix('Bearer ')
    return token if token.present?

    parsed = JSON.parse(response.body)
    parsed.dig('data', 'attributes', 'token')
  rescue JSON::ParserError
    nil
  end

  def api_auth_headers(user, password: 'SecureTest123!@#', token: nil, content_type: 'application/vnd.api+json')
    token ||= api_sign_in_and_get_token(user, password: password)
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => content_type,
      'Accept' => content_type
    }
  end
end

RSpec.configure do |config|
  config.include ApiAuthHelpers, type: :request
end
