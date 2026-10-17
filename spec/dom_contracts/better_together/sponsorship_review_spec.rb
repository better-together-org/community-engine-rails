# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the sponsorship token-based review page: asserts the
# stable identifiers that documentation screenshots (spec/docs_screenshots/
# better_together/sponsorship_panel_states_spec.rb) target. Runs in normal
# CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Sponsorship review DOM contract', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:beneficiary_person) { create(:better_together_person) }
  let(:sponsor_community) { create(:better_together_community) }

  describe 'GET /sponsorships/:token — pending, viewer is the beneficiary' do
    it 'exposes the decision action identifiers' do
      user = find_or_create_test_user('dom-contract-sponsorship-beneficiary@example.test', 'SecureTest123!@#', :user)
      sponsorship = create(:better_together_billing_sponsorship, sponsor: sponsor_community,
                                                                 beneficiary: user.person, status: 'pending')
      sign_in user

      get better_together.sponsorship_path(sponsorship.token, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="sponsorship-from-to-summary"')
      expect(response.body).to include('id="sponsorship-decision-actions"')
      expect(response.body).to include('id="sponsorship-accept-btn"')
      expect(response.body).to include('id="sponsorship-decline-btn"')
    end
  end

  describe 'GET /sponsorships/:token — pending, viewer is not authorized to decide' do
    it 'exposes the awaiting-beneficiary identifier' do
      sponsorship = create(:better_together_billing_sponsorship, sponsor: sponsor_community,
                                                                 beneficiary: beneficiary_person, status: 'pending')

      get better_together.sponsorship_path(sponsorship.token, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="sponsorship-awaiting-beneficiary-alert"')
    end
  end

  describe 'GET /sponsorships/:token — declined' do
    it 'exposes the declined identifier' do
      sponsorship = create(:better_together_billing_sponsorship, sponsor: sponsor_community,
                                                                 beneficiary: beneficiary_person, status: 'declined')

      get better_together.sponsorship_path(sponsorship.token, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="sponsorship-declined-alert"')
    end
  end

  describe 'GET /sponsorships/:token — active' do
    it 'exposes the active-state identifier' do
      sponsorship = create(:better_together_billing_sponsorship, sponsor: sponsor_community,
                                                                 beneficiary: beneficiary_person, status: 'active')

      get better_together.sponsorship_path(sponsorship.token, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="sponsorship-active-alert"')
    end
  end

  describe 'GET /sponsorships/:token — ended' do
    it 'exposes the ended identifier' do
      sponsorship = create(:better_together_billing_sponsorship, sponsor: sponsor_community,
                                                                 beneficiary: beneficiary_person, status: 'ended')

      get better_together.sponsorship_path(sponsorship.token, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="sponsorship-ended-alert"')
    end
  end
end
