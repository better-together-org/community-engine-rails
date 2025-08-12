require 'rails_helper'

RSpec.describe 'Turbo Native responses', type: :system do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  let(:current_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let(:conversation) do
    create(:better_together_conversation, creator: current_user.person).tap do |conv|
      conv.participants << current_user.person
    end
  end
  let(:navigation_area) { create(:better_together_navigation_area) }
  let(:navigation_item) { create(:better_together_navigation_item, navigation_area:) }

  describe 'NavigationItemsController' do
    it 'returns turbo stream for Turbo Native requests' do
      page.driver.header 'User-Agent', 'Turbo Native iOS'
      page.driver.header 'Accept', 'text/vnd.turbo-stream.html'
      page.driver.submit :patch,
                         navigation_area_navigation_item_path(navigation_area, navigation_item, locale: I18n.default_locale),
                         { navigation_item: { title: 'Updated' } }
      expect(page.html).to include('<turbo-stream')
    end

    it 'returns html for web requests' do
      page.driver.header 'Accept', 'text/html'
      page.driver.submit :patch,
                         navigation_area_navigation_item_path(navigation_area, navigation_item, locale: I18n.default_locale),
                         { navigation_item: { title: 'Updated' } }
      expect(page.html).not_to include('<turbo-stream')
    end
  end

  describe 'ConversationsController' do
    it 'returns turbo stream for Turbo Native requests' do
      page.driver.header 'User-Agent', 'Turbo Native iOS'
      visit conversation_path(conversation, locale: I18n.default_locale, format: :turbo_stream)
      expect(page.html).to include('<turbo-stream')
    end

    it 'returns html for web requests' do
      visit conversation_path(conversation, locale: I18n.default_locale)
      expect(page.html).not_to include('<turbo-stream')
    end
  end

  context 'Turbo.session.drive toggling', js: true do
    it 'toggles drive for native vs web' do
      visit conversation_path(conversation, locale: I18n.default_locale)
      expect(page.evaluate_script('Turbo.session.drive')).to eq true
      page.execute_script('Turbo.session.drive = false')
      expect(page.evaluate_script('Turbo.session.drive')).to eq false
    end
  end
end
