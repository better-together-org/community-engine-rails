# frozen_string_literal: true

require 'rspec/core'
require 'better_together/cookie_policy'

# Test support for gems and host apps that register cookie policy segments and consent providers:
#
#   require 'better_together/cookie_policy/rspec'
#
#   RSpec.describe 'my gem cookie policy' do
#     include_context 'with an isolated cookie policy registry'
#     let(:platform) { BetterTogether::Platform.new(name: 'Test') }
#     before { MyGem.register_cookie_policy! }
#
#     it_behaves_like 'a cookie policy segment', :my_gem, category: 'analytics'
#   end
module BetterTogether
  module CookiePolicy
    # Snapshot and restore both registries so a test can register freely.
    module TestHelpers
      def self.isolate
        segments = CookiePolicy.segments.dup
        providers = Consent.providers.dup
        yield
      ensure
        CookiePolicy.segments.replace(segments)
        Consent.providers.replace(providers)
      end
    end
  end
end

RSpec.shared_context 'with an isolated cookie policy registry' do
  around { |example| BetterTogether::CookiePolicy::TestHelpers.isolate { example.run } }
end

# Needs `platform` (any object the segment's condition and cookie callables accept).
RSpec.shared_examples 'a cookie policy segment' do |key, category:| # rubocop:disable Metrics/BlockLength
  let(:segment) { BetterTogether::CookiePolicy.resolved_segments(platform).find { |s| s.key == key.to_sym } }

  it 'is registered and visible for the platform', :aggregate_failures do
    expect(BetterTogether::CookiePolicy.segments).to have_key(key.to_sym)
    expect(segment).to be_present
    expect(segment.category).to eq(category.to_s)
  end

  it 'has a title and a description a visitor can read', :aggregate_failures do
    expect(segment.title).to be_present
    expect(segment.description).to be_present
  end

  it 'describes every cookie completely', :aggregate_failures do
    expect(segment.cookies).not_to be_empty
    segment.cookies.each do |cookie|
      expect(cookie.name).to be_present
      expect(cookie.purpose).to be_present
      expect(cookie.duration).to be_present
      expect(cookie.provider).to be_present if cookie.third_party?
    end
  end

  it 'links to the provider privacy information when any cookie is third-party' do
    next unless segment.cookies.any?(&:third_party?)

    expect(segment.privacy_url).to match(%r{\Ahttps://})
  end

  it 'counts toward the consent policy version when it needs consent' do
    next if category.to_s == 'essential'

    expect(BetterTogether::Consent.categories_in_use(platform)).to include(category.to_s)
  end
end
