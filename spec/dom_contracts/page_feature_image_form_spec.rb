# frozen_string_literal: true

require 'rails_helper'

# The page form exposes the feature image field under stable ids.
RSpec.describe 'Page feature image form DOM contract', type: :request do
  include RequestSpecHelper

  let!(:host_platform) { configure_host_platform }
  let(:page) { create(:better_together_page, platform: host_platform) }

  before do
    page
    login('manager@example.test', 'SecureTest123!@#')
    get "/#{I18n.default_locale}/pages/#{page.slug}/edit"
  end

  it 'renders the feature image field with its file input and remove flag', :aggregate_failures do
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="feature-image-fields"')
    expect(response.body).to include('id="feature-image-input"')
    expect(response.body).to include('id="feature-image-remove"')
  end

  it 'shows the localized label and hint', :aggregate_failures do
    expect(response.body).to include(I18n.t('activerecord.attributes.better_together/page.feature_image'))
    expect(response.body).to include(I18n.t('helpers.hint.images.feature_image'))
  end
end
