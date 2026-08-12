# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Sponsorships' do
  include ActiveJob::TestHelper

  let(:locale) { I18n.default_locale }
  let(:sponsor_user) do
    find_or_create_test_user("sponsorship-sponsor-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#')
  end
  let(:sponsor) { sponsor_user.person }
  let(:beneficiary_user) do
    find_or_create_test_user("sponsorship-beneficiary-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#')
  end
  let(:beneficiary) { beneficiary_user.person.tap { |person| person.update!(accepts_sponsorship: true) } }

  before { clear_enqueued_jobs }

  describe 'POST /:locale/sponsorships' do
    it 'creates a pending sponsorship offer and notifies the beneficiary' do
      sign_in sponsor_user

      post better_together.sponsorships_path(locale:),
           params: {
             sponsor_type: 'BetterTogether::Person', sponsor_id: sponsor.id,
             beneficiary_type: 'BetterTogether::Person', beneficiary_identifier: beneficiary.id
           }

      sponsorship = BetterTogether::Billing::Sponsorship.last
      expect(sponsorship).to be_status_pending
      expect(sponsorship.sponsor).to eq(sponsor)
      expect(sponsorship.beneficiary).to eq(beneficiary)
      expect(response).to redirect_to(better_together.sponsorship_path(sponsorship.token, locale:))
    end

    it 'redirects with an alert when the beneficiary has not opted in' do
      opted_out = find_or_create_test_user("sponsorship-optout-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#').person
      sign_in sponsor_user

      post better_together.sponsorships_path(locale:),
           params: {
             sponsor_type: 'BetterTogether::Person', sponsor_id: sponsor.id,
             beneficiary_type: 'BetterTogether::Person', beneficiary_identifier: opted_out.id
           }

      expect(BetterTogether::Billing::Sponsorship.count).to eq(0)
      expect(response).to have_http_status(:redirect)
    end

    it 'rejects creating an offer as someone else\'s sponsor' do
      sign_in sponsor_user
      other_person = find_or_create_test_user("sponsorship-other-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#').person

      post better_together.sponsorships_path(locale:),
           params: {
             sponsor_type: 'BetterTogether::Person', sponsor_id: other_person.id,
             beneficiary_type: 'BetterTogether::Person', beneficiary_identifier: beneficiary.id
           }

      # Pundit::NotAuthorizedError -> ApplicationController#user_not_authorized redirects back
      expect(response).to have_http_status(:redirect)
      expect(BetterTogether::Billing::Sponsorship.count).to eq(0)
    end

    it 'requires authentication' do
      post better_together.sponsorships_path(locale:),
           params: {
             sponsor_type: 'BetterTogether::Person', sponsor_id: sponsor.id,
             beneficiary_type: 'BetterTogether::Person', beneficiary_identifier: beneficiary.id
           }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /:locale/sponsorships/:token' do
    let!(:sponsorship) do
      create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'pending')
    end

    it 'shows the offer to an unauthenticated visitor without requiring sign-in' do
      get better_together.sponsorship_path(sponsorship.token, locale:)

      expect(response).to have_http_status(:ok)
    end

    it 'renders a 404-equivalent for an unknown token' do
      get better_together.sponsorship_path('not-a-real-token', locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /:locale/sponsorships/:token/accept' do
    let!(:sponsorship) do
      create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'pending')
    end

    it 'allows the beneficiary to accept' do
      sign_in beneficiary_user

      post better_together.accept_sponsorship_path(sponsorship.token, locale:)

      expect(sponsorship.reload).to be_status_accepted
      expect(response).to redirect_to(better_together.sponsorship_path(sponsorship.token, locale:))
    end

    it 'forbids the sponsor from accepting their own offer' do
      sign_in sponsor_user

      post better_together.accept_sponsorship_path(sponsorship.token, locale:)

      # Pundit::NotAuthorizedError -> ApplicationController#user_not_authorized redirects back
      expect(response).to have_http_status(:redirect)
      expect(sponsorship.reload).to be_status_pending
    end
  end

  describe 'POST /:locale/sponsorships/:token/decline' do
    let!(:sponsorship) do
      create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'pending')
    end

    it 'allows the beneficiary to decline' do
      sign_in beneficiary_user

      post better_together.decline_sponsorship_path(sponsorship.token, locale:)

      expect(sponsorship.reload).to be_status_declined
    end
  end

  describe 'POST /:locale/sponsorships/:id/end' do
    let!(:sponsorship) do
      create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'active')
    end

    it 'allows the sponsor to end an active sponsorship' do
      sign_in sponsor_user

      post better_together.end_sponsorship_path(sponsorship.id, locale:)

      expect(sponsorship.reload).to be_status_ended
    end

    it 'allows the beneficiary to end an active sponsorship' do
      sign_in beneficiary_user

      post better_together.end_sponsorship_path(sponsorship.id, locale:)

      expect(sponsorship.reload).to be_status_ended
    end

    it 'forbids a stranger from ending it' do
      stranger = find_or_create_test_user("sponsorship-stranger-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#')
      sign_in stranger

      post better_together.end_sponsorship_path(sponsorship.id, locale:)

      # Pundit::NotAuthorizedError -> ApplicationController#user_not_authorized redirects back
      expect(response).to have_http_status(:redirect)
      expect(sponsorship.reload).to be_status_active
    end
  end
end
