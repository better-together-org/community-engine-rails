# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'grouped notifications', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  let(:user_email) { 'user@example.test' }
  let(:user_password) { 'password12345' }
  let(:user) { create(:user, :confirmed, email: user_email, password: user_password) }
  let(:person) { user.person }
  let!(:message_one) { create(:message) }
  let!(:message_two) { create(:message) }

  before do
    configure_host_platform
    3.times { BetterTogether::NewMessageNotifier.with(record: message_one).deliver(person) }
    2.times { BetterTogether::NewMessageNotifier.with(record: message_two).deliver(person) }
    sign_in_user(user_email, user_password)
  end

  it 'displays notifications grouped by record with counts' do
    visit notifications_path(locale: I18n.default_locale)

    expect(page).to have_css('.notification', count: 2)
    expect(page).to have_css('.notification .notification-count', text: '3')
    expect(page).to have_css('.notification .notification-count', text: '2')
  end
end
