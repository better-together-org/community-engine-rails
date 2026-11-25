# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cookie consent endpoint', :no_auth do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:platform) { configure_host_platform }
  let(:user) { find_or_create_test_user('consent-user@example.test', 'SecureTest123!@#', :user) }
  let(:path) { better_together.settings_cookie_consent_path(locale:) }
  let(:version) { BetterTogether::Consent.policy_version(platform) }
  let(:json_headers) { { 'Accept' => 'application/json' } }

  before do
    platform
    BetterTogether.register_consent_provider(:test) { true }
  end

  after { BetterTogether::Consent.reset! }

  def cookie_header
    Array(response.headers['Set-Cookie']).join("\n")
  end

  def cookie_value
    raw = cookie_header[/#{BetterTogether::Consent::COOKIE}=([^;\n]*)/, 1]
    raw && JSON.parse(CGI.unescape(raw))
  end

  context 'when signed in' do
    before { sign_in user }

    it 'stores the decision on the person and rewrites the cookie', :aggregate_failures do
      patch path, params: { consent: { analytics: '1', marketing: '0' } }, headers: json_headers

      expect(response).to have_http_status(:ok)
      stored = BetterTogether::ConsentPreference.new(user.person.reload)
      expect(stored.decision).to eq('analytics' => true, 'marketing' => false)
      expect(stored.policy_version).to eq(version)
      expect(stored.decided_at).to be_within(1.minute).of(Time.current)
      expect(cookie_value).to include('v' => 1, 'analytics' => true, 'marketing' => false, 'pv' => version)
    end

    it 'sets the cookie with the same attributes as the banner', :aggregate_failures do
      patch path, params: { consent: { analytics: '1' } }, headers: json_headers

      line = cookie_header.lines.find { |l| l.start_with?("#{BetterTogether::Consent::COOKIE}=") }
      expect(line).to match(%r{path=/}i)
      expect(line).to match(/samesite=lax/i)
      expect(line).to match(/expires=/i)
      expect(line).not_to match(/httponly/i)
    end

    it 'returns the stored decision as JSON' do
      patch path, params: { consent: { analytics: '1' } }, headers: json_headers

      expect(response.parsed_body).to include('analytics' => true, 'marketing' => false, 'policy_version' => version)
    end

    it 'treats anything but a literal true as declined' do
      patch path, params: { consent: { analytics: 'maybe' } }, headers: json_headers

      expect(response.parsed_body).to include('analytics' => false, 'marketing' => false)
    end

    it 'accepts a JSON body', :aggregate_failures do
      patch path, params: { consent: { analytics: true, marketing: true } }.to_json,
                  headers: json_headers.merge('Content-Type' => 'application/json')

      expect(response).to have_http_status(:ok)
      expect(BetterTogether::ConsentPreference.new(user.person.reload).decision)
        .to eq('analytics' => true, 'marketing' => true)
    end

    it 'permits only the two booleans: the date, version and target person cannot be supplied', :aggregate_failures do
      other = create(:better_together_user, :confirmed)
      patch path, params: { person_id: other.person.id,
                            consent: { analytics: '1', decided_at: '1999-01-01', policy_version: 'forged',
                                       person_id: other.person.id } },
                  headers: json_headers

      expect(BetterTogether::ConsentPreference.new(other.person.reload).stored?).to be(false)
      stored = BetterTogether::ConsentPreference.new(user.person.reload)
      expect(stored.policy_version).to eq(version)
      expect(stored.decided_at.year).to eq(Time.current.year)
    end

    it 'withdraws everything when both categories are declined' do
      patch path, params: { consent: { analytics: '1', marketing: '1' } }, headers: json_headers
      patch path, params: { consent: { analytics: '0', marketing: '0' } }, headers: json_headers

      expect(BetterTogether::ConsentPreference.new(user.person.reload).decision)
        .to eq('analytics' => false, 'marketing' => false)
    end

    it 'redirects a plain form post back to the settings tab', :aggregate_failures do
      patch path, params: { consent: { analytics: '1' } }

      expect(response).to redirect_to(better_together.settings_path(locale:, anchor: 'cookie-consent'))
      expect(BetterTogether::ConsentPreference.new(user.person.reload).decision['analytics']).to be(true)
    end

    describe 'CSRF protection' do
      around do |example|
        original = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = original
      end

      it 'rejects a request without a token and stores nothing', :aggregate_failures do
        expect { patch path, params: { consent: { analytics: '1' } }, headers: json_headers }
          .to raise_error(ActionController::InvalidAuthenticityToken)
        expect(BetterTogether::ConsentPreference.new(user.person.reload).stored?).to be(false)
      end

      it 'accepts the request with the page token' do
        get better_together.settings_path(locale:)
        token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')['content']
        patch path, params: { consent: { analytics: '1' } }, headers: json_headers.merge('X-CSRF-Token' => token)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  context 'when signed out' do
    it 'is not routable, so nothing is stored and no cookie is set' do
      expect { patch path, params: { consent: { analytics: '1' } }, headers: json_headers }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
