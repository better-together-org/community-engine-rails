# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for message requests',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::DocsScreenshotHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }
  let(:recipient_user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:sender) { create(:better_together_person, name: 'Jordan Rivera', identifier: "jordan-rivera-#{SecureRandom.hex(3)}") }
  let(:message_request) do
    create(:better_together_message_request,
           sender:, recipient: recipient_user.person, platform: host_platform,
           note: 'Hi, I run the garden volunteers and would love to coordinate this season with you.')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    # message_requests is an alpha feature; docs capture it as a platform that has switched it on.
    host_platform.update!(feature_gate_rollouts: { 'message_requests' => 'stable' })
    recipient_user
    message_request
  end

  after do
    host_platform.update!(feature_gate_rollouts: {})
    Current.platform = nil
  end

  it 'captures the message request inbox' do
    docs_screenshot('message_requests_index', role: 'user', feature_set: 'message_requests') do
      capybara_login_as_user
      visit better_together.message_requests_path(locale:)

      expect(page).to have_text('Message Requests')
      expect(page).to have_text('Jordan Rivera')
      expect(page).to have_text('would like to message you')
      expect(page).to have_button('Accept', match: :first)
    end
  end

  it 'captures a single message request' do
    docs_screenshot('message_requests_show', role: 'user', feature_set: 'message_requests') do
      capybara_login_as_user
      visit better_together.message_request_path(message_request, locale:)

      expect(page).to have_text('Message Request')
      expect(page).to have_text('coordinate this season')
      expect(page).to have_button('Accept & Start Conversation')
    end
  end
end
