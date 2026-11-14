# frozen_string_literal: true

require 'rails_helper'

# The cookie policy page builds its cookie tables from the registry, so extensions need no text edits.
RSpec.describe 'better_together/static_pages/cookie_consent' do
  let(:platform) { instance_double(BetterTogether::Platform, name: 'Test Platform') }
  let(:signed_in) { false }
  let(:doc) { Nokogiri::HTML(rendered) }

  before do
    view.extend BetterTogether::ApplicationHelper
    allow(view).to receive_messages(host_platform: platform, user_signed_in?: signed_in)
    allow(view).to receive(:render).and_call_original
  end

  after { BetterTogether::Consent.reset! }

  def register_analytics(key = :ga, name: '_ga')
    BetterTogether.register_cookie_policy_segment(
      key, category: :analytics, title: "Segment #{key}", description: "About #{key}.",
           cookies: [{ name:, purpose: 'Counts visits', duration: '2 years', provider: 'Google', party: :third }],
           privacy_url: 'https://policies.google.com/privacy'
    )
  end

  context 'with no extensions' do
    before { render template: 'better_together/static_pages/cookie_consent' }

    it 'lists the essential cookies from the registry', :aggregate_failures do
      expect(doc.at_css('#cookie-policy-segment-session table')).to be_present
      expect(rendered).to include('_better_together_session', 'remember_user_token', 'bt_consent')
    end

    it 'shows no optional category headings and keeps the default statement', :aggregate_failures do
      expect(doc.at_css('#cookie-policy-category-analytics')).to be_nil
      expect(doc.at_css('#cookie-policy-category-marketing')).to be_nil
      expect(rendered).to include('does not include optional analytics or advertising cookies by default')
    end

    it 'has no empty headings' do
      empty = doc.css('h2, h3, h4').select { |heading| heading.text.strip.empty? }

      expect(empty).to be_empty
    end

    it 'shows the last updated date and the policy version', :aggregate_failures do
      expect(doc.at_css('#cookie-policy-updated').text).to include(BetterTogether::CookiePolicy.version(platform))
      expect(doc.at_css('#cookie-policy-updated').text).to include(I18n.l(BetterTogether::CookiePolicy::CORE_UPDATED_ON, format: :long))
    end
  end

  context 'with one extension segment' do
    before do
      register_analytics
      render template: 'better_together/static_pages/cookie_consent'
    end

    it 'adds its category, cookie table and privacy link', :aggregate_failures do
      expect(doc.at_css('#cookie-policy-category-analytics-title').text)
        .to eq(I18n.t('better_together.cookie_policy.categories.analytics.title'))
      expect(doc.css('#cookie-policy-segment-ga td code').map(&:text)).to eq(['_ga'])
      expect(doc.at_css('#cookie-policy-segment-ga a')['href']).to eq('https://policies.google.com/privacy')
      expect(doc.at_css('#cookie-policy-category-marketing')).to be_nil
    end

    it 'marks third-party cookies and replaces the "no optional cookies" statement', :aggregate_failures do
      expect(doc.at_css('#cookie-policy-segment-ga').text).to include(I18n.t('better_together.cookie_policy.party.third'))
      expect(rendered).not_to include('does not include optional analytics or advertising cookies by default')
    end
  end

  context 'with many extension segments' do
    before do
      register_analytics(:ga)
      register_analytics(:plausible, name: 'plausible_ignore')
      BetterTogether.register_cookie_policy_segment(:ads, category: :marketing, title: 'Ads', description: 'Ads.',
                                                          cookies: [{ name: '_ad', purpose: 'Ads', duration: '1 day', party: :first }])
      render template: 'better_together/static_pages/cookie_consent'
    end

    it 'groups the segments under their category in order', :aggregate_failures do
      expect(doc.css('#cookie-policy-category-analytics [id$="-title"]').map(&:text))
        .to include('Segment ga', 'Segment plausible')
      expect(doc.at_css('#cookie-policy-category-marketing #cookie-policy-segment-ads')).to be_present
      categories = doc.css('section[id^="cookie-policy-category-"]').map { |node| node['id'] }
      expect(categories).to eq(%w[cookie-policy-category-analytics cookie-policy-category-marketing])
    end
  end

  context 'when a segment is hidden for this platform' do
    before do
      BetterTogether.register_cookie_policy_segment(:ga, category: :analytics, title: 'Hidden', if: ->(_platform) { false })
      render template: 'better_together/static_pages/cookie_consent'
    end

    it 'leaves no trace of it', :aggregate_failures do
      expect(doc.at_css('#cookie-policy-category-analytics')).to be_nil
      expect(rendered).not_to include('Hidden')
    end
  end

  context 'with a host additions partial' do
    it 'renders the host partial after the optional cookies' do
      stub_template 'better_together/cookie_policy/_host_additions.html.erb' => '<p id="host-text">Our own words</p>'
      render template: 'better_together/static_pages/cookie_consent'

      expect(doc.at_css('#cookie-policy-host-additions #host-text').text).to eq('Our own words')
    end
  end

  context 'when signed in' do
    let(:signed_in) { true }

    it 'links to the settings cookie consent tab' do
      render template: 'better_together/static_pages/cookie_consent'

      expect(doc.at_css('#cookie-policy-manage a')['href']).to include('settings').and include('cookie-consent')
    end
  end
end
