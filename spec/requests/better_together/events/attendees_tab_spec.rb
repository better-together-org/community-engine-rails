# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event show attendees tab', type: :request do
  include DeviseSessionHelpers

  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    @manager_user = login_as_platform_manager
  end

  it 'shows attendees tab to organizers' do
    event = BetterTogether::Event.create!(
      name: 'Neighborhood Clean-up',
      starts_at: 1.day.from_now,
      identifier: SecureRandom.uuid,
      privacy: 'public',
      creator: @manager_user.person
    )

    get better_together.event_path(event, locale: locale)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Attendees')
  end
end
