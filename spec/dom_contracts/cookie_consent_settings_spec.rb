# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the cookie consent tab in the person's settings. Docs screenshot specs and the
# settings stylesheet target these identifiers.
RSpec.describe 'Cookie consent settings DOM contract', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:platform) { configure_host_platform }
  let(:user) { find_or_create_test_user('consent-dom@example.test', 'SecureTest123!@#', :user) }
  let(:doc) { Nokogiri::HTML(response.body) }

  before do
    platform
    sign_in user
  end

  after { BetterTogether::Consent.reset! }

  context 'with a provider that uses analytics only' do
    before do
      BetterTogether.register_consent_provider(:ga) { :analytics }
      BetterTogether.register_cookie_policy_segment(:ga, category: :analytics, title: 'Google Analytics',
                                                         description: 'Counts visits.',
                                                         cookies: [{ name: '_ga', purpose: 'x', duration: '2y', party: :third }])
      get better_together.settings_path(locale:)
    end

    it 'exposes the tab, form and controls with stable ids', :aggregate_failures do # rubocop:disable RSpec/MultipleExpectations
      %w[cookie-consent-tab cookie-consent cookie-consent-settings cookie-consent-form cookie-consent-stored
         cookie-consent-fieldset cookie-consent-essential cookie-consent-analytics cookie-consent-analytics-help
         cookie-consent-save cookie-consent-withdraw cookie-consent-status].each do |id|
        expect(doc.at_css("##{id}")).to be_present, "missing ##{id}"
      end
    end

    it 'lists only the categories something uses', :aggregate_failures do
      expect(doc.at_css('#cookie-consent-marketing')).to be_nil
      expect(doc.at_css('#cookie-consent-analytics-help').text).to include('Google Analytics')
    end

    it 'labels every switch and shows essential as always on', :aggregate_failures do
      %w[cookie-consent-essential cookie-consent-analytics].each do |id|
        expect(doc.at_css("label[for='#{id}']")).to be_present, "no label for #{id}"
        expect(doc.at_css("##{id}")['role']).to eq('switch')
      end
      essential = doc.at_css('#cookie-consent-essential')
      expect(essential.key?('disabled')).to be(true)
      expect(essential.key?('checked')).to be(true)
    end

    it 'wraps the choices in a fieldset with a legend and has a polite live region', :aggregate_failures do
      expect(doc.at_css('#cookie-consent-fieldset legend')).to be_present
      status = doc.at_css('#cookie-consent-status')
      expect(status['role']).to eq('status')
      expect(status['aria-live']).to eq('polite')
    end
  end

  context 'with analytics and marketing in use' do
    before do
      BetterTogether.register_consent_provider(:all) { true }
      get better_together.settings_path(locale:)
    end

    it 'shows both switches' do
      expect(doc.css('#cookie-consent-analytics, #cookie-consent-marketing').size).to eq(2)
    end
  end

  context 'with nothing that needs consent' do
    before { get better_together.settings_path(locale:) }

    it 'explains there is nothing to choose and offers no form', :aggregate_failures do
      expect(doc.at_css('#cookie-consent-none')).to be_present
      expect(doc.at_css('#cookie-consent-form')).to be_nil
    end
  end

  context 'with a stored decision' do
    before do
      BetterTogether.register_consent_provider(:all) { true }
      BetterTogether::ConsentPreference.new(user.person)
                                       .record!({ 'marketing' => true }, policy_version: BetterTogether::Consent.policy_version(platform))
      get better_together.settings_path(locale:)
    end

    it 'checks the stored categories and states the date', :aggregate_failures do
      expect(doc.at_css('#cookie-consent-marketing').key?('checked')).to be(true)
      expect(doc.at_css('#cookie-consent-analytics').key?('checked')).to be(false)
      expect(doc.at_css('#cookie-consent-stored').text).to include(I18n.l(Time.zone.today, format: :long))
    end
  end
end
