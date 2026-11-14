# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_feature_access_grant, class: BetterTogether::FeatureAccessGrant do
    platform do
      BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host)
    end
    person { association(:better_together_person) }
    granted_by_person { association(:better_together_person) }
    feature_key { 'device_permissions' }
    access_level { 'beta' }
    expires_at { 30.days.from_now }
  end
end
