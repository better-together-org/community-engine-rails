# frozen_string_literal: true

# Factories are shipped to host apps, whose specs do not load this gem's spec/support.
require_relative '../../support/host_roles'

FactoryBot.define do
  factory 'better_together/platform_trusted_domain',
          class: 'BetterTogether::PlatformTrustedDomain',
          aliases: %i[better_together_platform_trusted_domain platform_trusted_domain] do
    association :platform, factory: :'better_together/platform'
    sequence(:domain) { |n| "trusted#{n}.example.org" }
    enabled { true }
    include_subdomains { false }

    role { HostRoles.find!('community_member') }
  end
end
