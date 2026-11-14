# frozen_string_literal: true

require 'rails_helper'
require 'better_together/cookie_policy/rspec'

RSpec.describe BetterTogether::CookiePolicy do
  let(:platform) { instance_double(BetterTogether::Platform, name: 'Test') }

  after { BetterTogether::Consent.reset! }

  def register(key = :ga, **overrides)
    BetterTogether.register_cookie_policy_segment(
      key, category: :analytics, title: 'Google Analytics', description: 'Counts visits.',
           cookies: [{ name: '_ga', purpose: 'Distinguishes visitors', duration: '2 years',
                       provider: 'Google', party: :third }],
           privacy_url: 'https://policies.google.com/privacy', **overrides
    )
  end

  describe 'with no extensions' do
    it 'lists only the Community Engine essential cookies', :aggregate_failures do
      groups = described_class.grouped(platform)

      expect(groups.keys).to eq(%w[essential])
      names = groups['essential'].flat_map { |segment| segment.cookies.map(&:name) }
      expect(names).to include('_better_together_session', 'remember_user_token', 'bt_consent')
    end

    it 'translates the core wording' do
      session = described_class.resolved_segments(platform).find { |segment| segment.key == :session }

      expect(session.title).to eq(I18n.t('better_together.cookie_policy.core.session.title'))
    end

    it 'needs no consent categories' do
      expect(described_class.consent_categories(platform)).to be_empty
    end
  end

  describe '.register' do
    it 'groups segments by category in registration order', :aggregate_failures do
      register(:ga)
      register(:ads, category: :marketing, title: 'Ads')

      groups = described_class.grouped(platform)
      expect(groups.keys).to eq(%w[essential analytics marketing])
      expect(groups['analytics'].map(&:key)).to eq([:ga])
    end

    it 'replaces a segment registered again under the same key' do
      register(:ga)
      register(:ga, title: 'GA4')

      expect(described_class.segments_for_category(platform, :analytics).map(&:title)).to eq(['GA4'])
    end

    it 'rejects an unknown category' do
      expect { register(:bad, category: :tracking) }.to raise_error(ArgumentError, /category/)
    end

    it 'passes literals through and translates i18n keys', :aggregate_failures do
      register(:ga, title: 'better_together.consent.title', description: 'Plain text. Not a key')

      segment = described_class.segments_for_category(platform, :analytics).first
      expect(segment.title).to eq(I18n.t('better_together.consent.title'))
      expect(segment.description).to eq('Plain text. Not a key')
    end

    it 'evaluates cookies per platform when given a callable' do
      register(:ga, cookies: lambda { |p|
        [{ name: "_ga_#{p.name}", purpose: 'x', duration: '1 day', provider: 'Google', party: :third }]
      })

      expect(described_class.segments_for_category(platform, :analytics).first.cookies.map(&:name)).to eq(['_ga_Test'])
    end

    it 'hides a segment when its condition is false and shows it when true', :aggregate_failures do
      register(:ga, if: ->(p) { p.name == 'Other' })
      expect(described_class.consent_categories(platform)).to be_empty

      register(:ga, if: ->(p) { p.name == 'Test' })
      expect(described_class.consent_categories(platform)).to eq(%w[analytics])
    end

    it 'keeps a segment visible when its condition raises' do
      register(:ga, if: ->(_p) { raise 'boom' })

      expect(described_class.consent_categories(platform)).to eq(%w[analytics])
    end

    it 'drops the cookie list but keeps the segment when the cookie callable raises' do
      register(:ga, cookies: ->(_p) { raise 'boom' })

      expect(described_class.segments_for_category(platform, :analytics).first.cookies).to eq([])
    end
  end

  describe 'version and last updated' do
    it 'changes the version when a segment appears', :aggregate_failures do
      before = described_class.version(platform)
      register
      expect(described_class.version(platform)).not_to eq(before)
    end

    it 'uses the core date when no extension is newer, and the newest segment date otherwise', :aggregate_failures do
      expect(described_class.last_updated(platform)).to eq(described_class::CORE_UPDATED_ON)

      register(:ga, updated_on: Date.new(2030, 1, 2))
      register(:old, title: 'Old', updated_on: Date.new(2020, 1, 1))
      expect(described_class.last_updated(platform)).to eq(Date.new(2030, 1, 2))
    end
  end

  describe 'consent policy version' do
    it 'changes when a non-essential segment appears and when a provider appears', :aggregate_failures do
      base = BetterTogether::Consent.policy_version(platform)
      register
      with_segment = BetterTogether::Consent.policy_version(platform)
      BetterTogether.register_consent_provider(:ga) { :analytics }
      with_provider = BetterTogether::Consent.policy_version(platform)

      expect([base, with_segment, with_provider].uniq.size).to eq(3)
    end

    it 'does not change when an essential segment is added' do
      base = BetterTogether::Consent.policy_version(platform)
      register(:extra, category: :essential, title: 'Extra', cookies: [])

      expect(BetterTogether::Consent.policy_version(platform)).to eq(base)
    end
  end

  describe 'shared example for extension gems' do
    include_context 'with an isolated cookie policy registry'

    before { register(:ga) }

    it_behaves_like 'a cookie policy segment', :ga, category: 'analytics'
  end
end
