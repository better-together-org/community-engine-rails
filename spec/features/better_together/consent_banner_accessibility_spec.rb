# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Consent banner accessibility', # rubocop:disable RSpec/DescribeClass
               :accessibility, :as_user, :js, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa] }

  before do
    BetterTogether::PlatformSnippet.create!(platform: host_platform, name: 'Stats', location: 'head_end',
                                            kind: 'script_inline', content: 'window.statsLoaded = true;',
                                            consent_category: 'analytics', enabled: true)
  end

  it 'passes WCAG 2.1 AA in each locale with 44px targets', :aggregate_failures do
    I18n.available_locales.each do |locale|
      visit better_together.new_user_session_path(locale:)
      expect(page).to have_css('#consent-banner', wait: 10)
      expect(page).to be_axe_clean.within('#consent-banner-region').according_to(*wcag)

      %w[consent-accept-all consent-essential-only consent-choose].each do |id|
        size = page.evaluate_script("(function(){var r=document.getElementById('#{id}').getBoundingClientRect();return [r.width,r.height]})()")
        expect(size.last).to be >= 44
      end
    end
  end

  it 'moves focus into the choices, saves them, and keeps a preferences control', :aggregate_failures do
    visit better_together.new_user_session_path
    find('#consent-choose').click
    expect(page).to have_css('#consent-choices', visible: :visible)
    expect(page.evaluate_script('document.activeElement.id')).to eq('consent-analytics')
    expect(find('#consent-choose')['aria-expanded']).to eq('true')

    expect(page).to be_axe_clean.within('#consent-banner-region').according_to(*wcag)

    find('#consent-essential-only').click
    expect(page).to have_no_css('#consent-banner', visible: :visible)
    expect(page).to have_css('#consent-preferences-link', visible: :visible)
  end

  it 'announces the decision to page code through a window event', :aggregate_failures do
    visit better_together.new_user_session_path
    page.execute_script("window.addEventListener('better_together:consent', e => { sessionStorage.setItem('heard', JSON.stringify(e.detail)) })")
    find('#consent-essential-only').click
    expect(page).to have_css('#consent-preferences-link', visible: :visible, wait: 10)
    expect(JSON.parse(page.evaluate_script("sessionStorage.getItem('heard')")))
      .to eq('analytics' => false, 'marketing' => false)
  end
end
