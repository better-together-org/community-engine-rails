# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/platform_trusted_domain',
          class: 'BetterTogether::PlatformTrustedDomain',
          aliases: %i[better_together_platform_trusted_domain platform_trusted_domain] do
    association :platform, factory: :'better_together/platform'
    sequence(:domain) { |n| "trusted#{n}.example.org" }
    enabled { true }
    include_subdomains { false }

    role { BetterTogether::Role.find_by!(identifier: 'community_member') }
  end
end
