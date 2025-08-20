# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CalendarsController' do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  it 'renders index' do
    get better_together.calendars_path(locale:)
    expect(response).to have_http_status(:ok)
  end
end
