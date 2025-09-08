# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitation expiry access control' do
  include RequestSpecHelper
  include ActiveSupport::Testing::TimeHelpers

  before do
    configure_host_platform
    # Force private platform to exercise the privacy gate
    BetterTogether::Platform.find_by(host: true)&.update!(privacy: 'private')
  end

  let(:invitation) { create(:better_together_platform_invitation, status: 'pending', locale: I18n.default_locale.to_s) }

  # rubocop:todo RSpec/MultipleExpectations
  it 'allows access with a valid invitation token and denies after expiry' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    # First request with invitation_code should store token + expiry in session and allow access
    get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)
    expect(response).to have_http_status(:ok)

    # Advance time beyond expiry window (30 minutes + 1s)
    travel 31.minutes

    # Next request without re-supplying the code should now be denied (redirect to sign-in)
    get better_together.home_page_path(locale: I18n.default_locale)
    expect(response).to redirect_to(better_together.new_user_session_path(locale: I18n.default_locale))
  ensure
    travel_back
  end
end
