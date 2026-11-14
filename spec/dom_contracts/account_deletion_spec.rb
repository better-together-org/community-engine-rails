# frozen_string_literal: true

require 'rails_helper'

# Stable ids on the account deletion screens, used by docs screenshots and feature specs.
RSpec.describe 'Account deletion DOM contract', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:password) { 'SecureTest123!@#' }
  let!(:platform) { configure_host_platform }
  let(:steward_role) { BetterTogether::Role.find_by!(identifier: 'platform_steward') }
  let(:page_html) { Nokogiri::HTML(response.body) }

  def sign_in_as(email)
    user = create(:better_together_user, :confirmed, email:, password:, password_confirmation: password, platform:)
    yield user if block_given?
    login(email, password)
    user
  end

  def sole_steward!(user)
    BetterTogether::PersonPlatformMembership.where(joinable: platform, role: steward_role).destroy_all
    BetterTogether::PersonPlatformMembership.create!(member: user.person, joinable: platform, role: steward_role,
                                                     status: 'active')
  end

  it 'gives a member the request form and submit button', :aggregate_failures do
    sign_in_as('dom-member@example.test')
    get better_together.edit_user_registration_path(locale: I18n.default_locale)

    expect(page_html.css('#person-deletion-request-form').size).to eq(1)
    expect(page_html.css('#submit-person-deletion-request-btn').size).to eq(1)
    expect(page_html.css('label[for="person_deletion_request_requested_reason"]').size).to eq(1)
    expect(page_html.css('textarea#person_deletion_request_requested_reason').size).to eq(1)
    expect(page_html.css('#last-steward-deletion-notice').size).to eq(0)
  end

  it 'gives the last steward the notice and link', :aggregate_failures do
    sign_in_as('dom-steward@example.test') { |user| sole_steward!(user) }
    get better_together.edit_user_registration_path(locale: I18n.default_locale)

    expect(page_html.css('#last-steward-deletion-notice').size).to eq(1)
    expect(page_html.css('#platform-deletion-request-link').size).to eq(1)
  end

  it 'renders the platform removal form with its ids', :aggregate_failures do
    sign_in_as('dom-form@example.test') { |user| sole_steward!(user) }
    get better_together.new_platform_deletion_request_path(locale: I18n.default_locale)

    %w[platform-deletion-request-page platform-deletion-request-title platform-deletion-request-form
       submit-platform-deletion-request-btn platform-deletion-request-back].each do |id|
      expect(page_html.css("##{id}").size).to eq(1), "missing ##{id}"
    end
    expect(page_html.css('label[for="platform_deletion_request_requested_reason"]').size).to eq(1)
    expect(page_html.css('textarea#platform_deletion_request_requested_reason').size).to eq(1)
  end
end
