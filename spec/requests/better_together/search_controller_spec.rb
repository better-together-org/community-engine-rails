# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::SearchController', :as_user do
  let(:locale) { I18n.default_locale }

  it 'renders search results page' do
    get better_together.search_path(locale:), params: { q: 'test' }
    expect(response).to have_http_status(:ok)
  end
end
