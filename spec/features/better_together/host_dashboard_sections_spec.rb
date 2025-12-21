# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Host dashboard sections', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  scenario 'renders engagement, exchange, events, infrastructure, and geography resource cards' do
    visit better_together.host_dashboard_path(locale:)

    expect(page).to have_content(I18n.t('host_dashboard.index.content_block_types', locale:))
    expect(page).to have_content(I18n.t('host_dashboard.index.engagement', locale:))
    expect(page).to have_content(I18n.t('host_dashboard.index.exchange', locale:))
    expect(page).to have_content(I18n.t('host_dashboard.index.events', locale:))
    expect(page).to have_content(I18n.t('host_dashboard.index.infrastructure', locale:))

    BetterTogether::Content::Block.load_all_subclasses
    BetterTogether::Content::Block.descendants.each do |klass|
      expect(page).to have_content(klass.model_name.human.pluralize(2, locale))
    end

    expected_cards = [
      BetterTogether::Post.model_name.human.pluralize(2, locale),
      BetterTogether::Comment.model_name.human.pluralize(2, locale),
      BetterTogether::CallForInterest.model_name.human.pluralize(2, locale),
      BetterTogether::Joatu::Offer.model_name.human.pluralize(2, locale),
      BetterTogether::Joatu::Request.model_name.human.pluralize(2, locale),
      BetterTogether::Joatu::Agreement.model_name.human.pluralize(2, locale),
      BetterTogether::Joatu::Category.model_name.human.pluralize(2, locale),
      BetterTogether::Joatu::ResponseLink.model_name.human.pluralize(2, locale),
      BetterTogether::Event.model_name.human.pluralize(2, locale),
      BetterTogether::EventInvitation.model_name.human.pluralize(2, locale),
      BetterTogether::EventAttendance.model_name.human.pluralize(2, locale),
      BetterTogether::Calendar.model_name.human.pluralize(2, locale),
      BetterTogether::CalendarEntry.model_name.human.pluralize(2, locale),
      BetterTogether::Infrastructure::Building.model_name.human.pluralize(2, locale),
      BetterTogether::Infrastructure::Floor.model_name.human.pluralize(2, locale),
      BetterTogether::Infrastructure::Room.model_name.human.pluralize(2, locale),
      BetterTogether::Geography::Map.model_name.human.pluralize(2, locale),
      BetterTogether::Geography::Space.model_name.human.pluralize(2, locale)
    ]

    expected_cards.each do |card_title|
      expect(page).to have_content(card_title)
    end
  end
end
