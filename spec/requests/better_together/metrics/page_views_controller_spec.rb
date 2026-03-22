# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::PageViewsController' do
  let(:locale) { I18n.default_locale }

  # rubocop:todo RSpec/MultipleExpectations
  it 'creates a page view with valid params' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    page = create(:better_together_page)

    post better_together.metrics_page_views_path(locale:), params: {
      viewable_type: page.class.name,
      viewable_id: page.id,
      locale: locale.to_s
    }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['success']).to be(true)
  end

  it 'returns 422 for invalid viewable' do
    post better_together.metrics_page_views_path(locale:), params: {
      viewable_type: 'NonExistent',
      viewable_id: '123',
      locale: locale.to_s
    }

    expect(response).to have_http_status(:unprocessable_content)
  end
end
