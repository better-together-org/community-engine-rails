# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_platform_association, class: 'BetterTogether::PlatformAssociation',
                                                 aliases: %i[platform_association] do
    operator_platform { create(:better_together_platform, type: 'BetterTogether::OperatorPlatform') }
    managed_platform { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
    granted_scopes { %w[read support] }
    status { 'requested' }
    transport { 'direct' }

    trait :active do
      status { 'active' }
      accepted_at { Time.current }
    end

    trait :suspended do
      status { 'suspended' }
    end

    trait :revoked do
      status { 'revoked' }
    end

    trait :remote_operator do
      operator_platform do
        create(:better_together_platform, :remote, type: 'BetterTogether::OperatorPlatform')
      end
      transport { 'http' }
    end
  end
end
