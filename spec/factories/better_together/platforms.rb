# frozen_string_literal: true

# spec/factories/platforms.rb

FactoryBot.define do
  factory 'better_together/platform',
          class: 'BetterTogether::Platform',
          aliases: %i[better_together_platform platform] do
    id { SecureRandom.uuid }
    name { "#{Faker::Company.unique.name} #{SecureRandom.hex(3)}" }
    description { Faker::Lorem.paragraph }
    identifier { "platform-#{SecureRandom.hex(10)}" }
    # Ensure uniqueness to avoid validation collisions across parallel specs
    host_url { "http://platform-#{SecureRandom.hex(6)}.test" }
    host { false }
    # Use IANA timezone identifiers from TZInfo
    time_zone { TZInfo::Timezone.all_identifiers.sample }
    privacy { 'private' }
    locality { 'local' }
    # community # Assumes a factory for BetterTogether::Community exists

    trait :host do
      host { true }
      protected { true }
    end

    trait :remote do
      locality { 'remote' }
      host { false }
      software_variant { 'generic' }
      federation_protocol { nil }
      oauth_issuer_url { nil }
    end

    trait :oauth_provider do
      locality { 'remote' }
      host { false }
      name { %w[GitHub Facebook Google Twitter].sample }
      url { "https://#{name.downcase}-#{SecureRandom.hex(4)}.com" }
    end

    trait :public do
      privacy { 'public' }
    end

    trait :membership_requests_enabled do
      allow_membership_requests { true }
    end

    trait :community_engine_peer do
      locality { 'remote' }
      host { false }
      software_variant { 'community_engine' }
      federation_protocol { 'ce_oauth' }
      oauth_issuer_url { host_url }
    end
  end
end
