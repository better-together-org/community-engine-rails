# frozen_string_literal: true

require 'rails_helper'

# While signed in, the stored decision is the source of truth and the cookie is refreshed on every visit.
RSpec.describe 'Consent cookie sync', :no_auth do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:platform) { configure_host_platform }
  let(:user) { find_or_create_test_user('consent-sync@example.test', 'SecureTest123!@#', :user) }
  let(:page_path) { better_together.new_user_session_path(locale:) }
  let(:version) { BetterTogether::Consent.policy_version(platform) }
  let(:preference) { BetterTogether::ConsentPreference.new(user.person) }

  before do
    platform
    BetterTogether.register_consent_provider(:test) { %i[analytics marketing] }
  end

  after { BetterTogether::Consent.reset! }

  def with_cookie(decision, policy_version = version)
    value = CGI.escape(BetterTogether::Consent.serialize(decision, policy_version))
    { 'HTTP_COOKIE' => "#{BetterTogether::Consent::COOKIE}=#{value}" }
  end

  def written_cookie
    raw = Array(response.headers['Set-Cookie']).join("\n")[/#{BetterTogether::Consent::COOKIE}=([^;\n]*)/, 1]
    raw && JSON.parse(CGI.unescape(raw))
  end

  def banner_hidden?
    Nokogiri::HTML(response.body).at_css('#consent-banner').key?('hidden')
  end

  def get_settings(headers = {})
    get better_together.settings_path(locale:), headers:
  end

  context 'when signed in with a stored decision' do
    before do
      preference.record!({ 'analytics' => true }, policy_version: version)
      sign_in user
    end

    it 'writes the cookie when it is missing so the page renders with no banner flash', :aggregate_failures do
      get_settings

      expect(written_cookie).to include('analytics' => true, 'marketing' => false, 'pv' => version)
      expect(banner_hidden?).to be(true)
    end

    it 'overwrites a cookie that differs: the stored decision wins', :aggregate_failures do
      get_settings(with_cookie({ 'analytics' => false, 'marketing' => true }))

      expect(written_cookie).to include('analytics' => true, 'marketing' => false)
      expect(BetterTogether::ConsentPreference.new(user.person.reload).decision)
        .to eq('analytics' => true, 'marketing' => false)
    end

    it 'refreshes the expiry on every visit even when the cookie already matches', :aggregate_failures do
      get_settings(with_cookie({ 'analytics' => true, 'marketing' => false }))

      expect(written_cookie).to include('analytics' => true)
      expect(Array(response.headers['Set-Cookie']).join).to match(/expires=/i)
    end

    it 'applies the stored decision to server-side gating in the same request' do
      BetterTogether::PlatformSnippet.create!(platform:, name: 'Stats', location: 'head_end', kind: 'script_inline',
                                              content: 'statsRan()', consent_category: 'analytics', enabled: true)
      get_settings

      expect(response.body).to include('statsRan()')
    end

    it 'does not write the cookie on non-GET requests' do
      patch better_together.update_settings_preferences_path(locale:), params: { person: { locale: 'en' } }

      expect(written_cookie).to be_nil
    end
  end

  context 'when a visitor decided anonymously and then signs in' do
    before { sign_in user }

    it 'adopts the cookie decision into the record when the person has none', :aggregate_failures do
      get_settings(with_cookie({ 'analytics' => true, 'marketing' => true }))

      expect(BetterTogether::ConsentPreference.new(user.person.reload).decision)
        .to eq('analytics' => true, 'marketing' => true)
      expect(written_cookie).to include('analytics' => true, 'marketing' => true)
    end

    it 'lets the stored decision win over a different cookie and overwrites the cookie', :aggregate_failures do
      preference.record!({ 'analytics' => false, 'marketing' => false }, policy_version: version)
      get_settings(with_cookie({ 'analytics' => true, 'marketing' => true }))

      expect(written_cookie).to include('analytics' => false, 'marketing' => false)
      expect(BetterTogether::ConsentPreference.new(user.person.reload).decision['analytics']).to be(false)
    end

    it 'does not adopt a cookie made under an older policy version', :aggregate_failures do
      get_settings(with_cookie({ 'analytics' => true }, 'stale'))

      expect(BetterTogether::ConsentPreference.new(user.person.reload).stored?).to be(false)
      expect(written_cookie).to be_nil
    end
  end

  context 'when the consent policy version changes' do
    before do
      preference.record!({ 'analytics' => true }, policy_version: 'older')
      sign_in user
    end

    it 'does not apply the outdated decision and shows the banner again', :aggregate_failures do
      get_settings(with_cookie({ 'analytics' => true }, 'older'))

      expect(written_cookie).to be_nil
      expect(banner_hidden?).to be(false)
    end

    it 're-prompts when a new provider category appears', :aggregate_failures do
      preference.record!({ 'analytics' => true }, policy_version: version)
      BetterTogether.register_consent_provider(:another) { :marketing }
      BetterTogether.register_cookie_policy_segment(:another, category: :marketing, title: 'Another')
      get_settings

      expect(written_cookie).to be_nil
      expect(response.body).to include('id="consent-banner"')
    end
  end

  context 'when anonymous' do
    it 'leaves the cookie alone', :aggregate_failures do
      get page_path

      expect(written_cookie).to be_nil
      expect(response.body).to include('id="consent-banner"')
    end

    it 'accepts a visitor decision in the cookie for gating' do
      BetterTogether::PlatformSnippet.create!(platform:, name: 'Stats', location: 'head_end', kind: 'script_inline',
                                              content: 'statsRan()', consent_category: 'analytics', enabled: true)
      get page_path, headers: with_cookie({ 'analytics' => true })

      expect(response.body).to include('statsRan()')
    end
  end

  context 'when signing out' do
    it 'leaves the cookie as the browser has it', :aggregate_failures do
      preference.record!({ 'analytics' => true }, policy_version: version)
      sign_in user
      delete better_together.destroy_user_session_path(locale:)

      expect(written_cookie).to be_nil
    end
  end
end
