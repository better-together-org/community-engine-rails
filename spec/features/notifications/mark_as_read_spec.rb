# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'message notifications' do
  include BetterTogether::DeviseSessionHelpers

  let(:user) { create(:user, :confirmed) }
  let(:conversation) { create(:conversation) }
  let!(:conversation_participant) do # rubocop:todo RSpec/LetSetup
    create(:conversation_participant,
           conversation: conversation,
           person: user.person)
  end
  let(:cp) do
    create(:conversation_participant,
           conversation: conversation)
  end

  before do
    configure_host_platform
    logout(:user)
    login_as(user, scope: :user)
  end

  it 'does not be marked as read if conversation is not loaded', :js do
    create_list(:message, 2, conversation: conversation)
    expect(user.person.notifications.map(&:read_at)).to all(be_nil)
  end

  it 'marked as read when conversation is loaded', :js do
    create_list(:message, 2, conversation: conversation)
    visit conversation_path(id: conversation, person_id: user.person, locale: I18n.default_locale)
    expect(user.person.notifications.map(&:read_at)).to all(be_a(Time))
  end

  # TODO: test for automatic update of read_at when page is active
  # it 'marked as read while conversation page is active', :js do
  #   visit conversation_path(id: conversation, person_id: user.person, locale: I18n.default_locale)
  #   create_list(:message, 2, conversation: conversation)
  #   expect(user.person.notifications.map(&:read_at)).to all(be_a(Time))
  # end
end
