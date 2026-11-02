# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_quota_grant, class: BetterTogether::QuotaGrant do
    platform do
      BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host)
    end
    owner { association(:better_together_person) }
    granted_by { association(:better_together_person) }
    quota_type { 'media_storage' }
    limit { 10 * (1024**3) }
    reason { 'Extra storage for community event coverage' }
  end
end
