# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Event self-service publishing agreement gate', :as_user do
  let(:host_platform) { configure_host_platform }
  let(:host_community) { host_platform.community }
  let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
  let(:password) { 'SecureTest123!@#' }
  let(:member_user) do
    create(:better_together_user, :confirmed, password: password)
  end
  let(:publishing_agreement) do
    BetterTogether::Agreement.find_or_create_by!(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
  end

  before do
    BetterTogether::PersonCommunityMembership.create!(
      joinable: host_community, member: member_user.person, role: member_role, status: 'active'
    )
    capybara_sign_in_user(member_user.email, password)
  end

  scenario 'a member without the agreement is redirected to it, and can reach the form once accepted' do
    visit better_together.new_event_path(locale: I18n.default_locale)

    expect(page).to have_current_path(%r{/agreements/}, ignore_query: true)
    expect(page.current_path).to include(publishing_agreement.slug)

    # Simulate acceptance (the production accept flow is a JS modal — this
    # records the same AgreementParticipant state that flow leaves behind).
    BetterTogether::AgreementParticipant.find_or_create_by!(
      agreement: publishing_agreement, participant: member_user.person
    ) { |p| p.accepted_at = Time.current }

    visit better_together.new_event_path(locale: I18n.default_locale)

    expect(page).to have_current_path(better_together.new_event_path(locale: I18n.default_locale), ignore_query: true)
    expect(page).to have_selector('form')
  end
end
