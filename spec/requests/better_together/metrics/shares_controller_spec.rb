# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::SharesController' do
  let(:locale) { I18n.default_locale }
  # rubocop:todo RSpec/MultipleExpectations
  it 'tracks a share with valid params' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations

    post better_together.metrics_shares_path(locale:), params: {
      platform: 'facebook',
      url: 'http://127.0.0.1:3000/post/1',
      shareable_type: 'BetterTogether::Post',
      shareable_id: SecureRandom.uuid
    }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['success']).to be(true)
  end

  it 'returns 422 for invalid platform/url' do
    post better_together.metrics_shares_path(locale:), params: { platform: 'unknown', url: 'notaurl' }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
