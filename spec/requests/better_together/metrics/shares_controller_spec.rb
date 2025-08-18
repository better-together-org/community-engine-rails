# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::SharesController', type: :request do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  it 'tracks a share with valid params' do
    post better_together.metrics_shares_path(locale:), params: {
      platform: 'facebook',
      url: 'https://example.com/post/1',
      shareable_type: 'BetterTogether::Post',
      shareable_id: SecureRandom.uuid
    }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['success']).to eq(true)
  end

  it 'returns 422 for invalid platform/url' do
    post better_together.metrics_shares_path(locale:), params: { platform: 'unknown', url: 'notaurl' }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
