# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'message notifications', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  let(:user) { create(:user, :confirmed) }
  let(:conversation) { create(:conversation) }
  let!(:conversation_participant) do
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
    sign_in_user(user.email, user.password)
  end

  it 'marked as read when conversation is loaded', :js do
    create_list(:message, 2, conversation: conversation)
    visit conversation_path(id: conversation, person_id: user.person, locale: I18n.default_locale)
    expect(user.person.notifications.map(&:read_at)).to all(be_a(Time))
  end
end
