# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::SearchController', type: :request do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  it 'renders search results page' do
    get better_together.search_path(locale:), params: { q: 'test' }
    expect(response).to have_http_status(:ok)
  end
end
