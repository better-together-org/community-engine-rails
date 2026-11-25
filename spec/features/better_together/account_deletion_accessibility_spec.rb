# frozen_string_literal: true

require 'rails_helper'

# WCAG 2.1 AA scan of the account deletion screens: the member request form, the last steward
# notice, and the platform removal request (form and pending state).
RSpec.describe 'Account deletion accessibility', :accessibility, :js, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let(:password) { 'SecureTest123!@#' }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:steward_role) { BetterTogether::Role.find_by!(identifier: 'platform_steward') }

  before { Current.platform = host_platform }

  after { Current.platform = nil }

  def sole_steward
    BetterTogether::PersonPlatformMembership.where(joinable: host_platform, role: steward_role).destroy_all
    user = find_or_create_test_user('steward-a11y@example.test', password, :user)
    BetterTogether::PersonPlatformMembership.create!(member: user.person, joinable: host_platform,
                                                     role: steward_role, status: 'active')
    user
  end

  def expect_axe_clean(selector)
    expect(page).to have_css(selector, wait: 10)
    expect(page).to be_axe_clean.within(selector).according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  it 'passes for the member deletion request form' do
    user = find_or_create_test_user('member-a11y@example.test', password, :user)
    capybara_sign_in_user(user.email, password)
    visit edit_user_registration_path(locale: I18n.default_locale)

    expect_axe_clean('#person-deletion-request-form')
  end

  it 'passes for the last steward notice' do
    steward = sole_steward
    capybara_sign_in_user(steward.email, password)
    visit edit_user_registration_path(locale: I18n.default_locale)

    expect_axe_clean('#last-steward-deletion-notice')
  end

  it 'passes for the platform removal request form and its pending state' do
    steward = sole_steward
    capybara_sign_in_user(steward.email, password)
    visit new_platform_deletion_request_path(locale: I18n.default_locale)
    expect_axe_clean('#platform-deletion-request-page')

    BetterTogether::PlatformDeletionRequest.create!(platform: host_platform, requested_by: steward.person,
                                                    requested_at: Time.current)
    visit new_platform_deletion_request_path(locale: I18n.default_locale)
    expect_axe_clean('#platform-deletion-request-page')
  end
end
