# frozen_string_literal: true

require 'rails_helper'

# The navigation item form lets stewards pick a route by name. Every entry in
# NavigationItem.route_names needs a label in every available locale, so adding a
# route without translating it fails here instead of showing a raw key or an
# English label to French, Spanish or Ukrainian stewards.
RSpec.describe 'Navigation item route name translations', type: :helper do # rubocop:disable RSpec/DescribeClass
  let(:route_names) { BetterTogether::NavigationItem.route_names.keys }

  it 'covers a non-empty route list' do
    expect(route_names).not_to be_empty
  end

  I18n.available_locales.each do |locale|
    it "translates every route name in #{locale}" do
      missing = route_names.reject do |name|
        I18n.exists?("better_together.navigation_items.route_names.#{name}", locale)
      end

      expect(missing).to be_empty,
                         "Add better_together.navigation_items.route_names.{#{missing.join(', ')}} to config/locales/#{locale}.yml"
    end
  end

  it 'has no translation for a route that is not in the list (stale keys)' do
    stale = I18n.t('better_together.navigation_items.route_names', locale: :en).keys.map(&:to_s) -
            route_names.map(&:to_s)

    expect(stale).to be_empty, "Remove unused route name translations: #{stale.join(', ')}"
  end

  it 'uses real Ukrainian text, not the English fallback' do
    untranslated = route_names.select do |name|
      I18n.t("better_together.navigation_items.route_names.#{name}", locale: :uk) !~ /\p{Cyrillic}/ &&
        name != :oauth_applications
    end

    expect(untranslated).to be_empty, "Translate into Ukrainian: #{untranslated.join(', ')}"
  end

  describe 'the route name picker options' do
    before { helper.extend(BetterTogether::NavigationItemsHelper) }

    I18n.available_locales.each do |locale|
      it "renders only translated labels in #{locale}" do
        I18n.with_locale(locale) do
          html = helper.route_names_for_select
          expect(html).not_to match(/translation missing/i)
          route_names.each do |name|
            expect(html).to include(ERB::Util.html_escape(I18n.t("better_together.navigation_items.route_names.#{name}"))),
                            "#{name} missing in #{locale} picker"
          end
        end
      end
    end
  end
end
