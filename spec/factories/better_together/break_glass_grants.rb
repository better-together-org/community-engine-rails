# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_break_glass_grant, class: 'BetterTogether::BreakGlassGrant' do
    association :subject, factory: :better_together_community
    association :grantee, factory: :better_together_person
    requested_by { grantee }
    platform { subject.platform }
    status { 'requested' }
    reason { 'Safety case 42 needs the private community content reviewed.' }
    emergency { false }
    available_at { 25.hours.ago }
    expires_at { 1.hour.from_now }

    trait :pending do
      available_at { 1.hour.from_now }
      expires_at { 25.hours.from_now }
    end

    trait :expired do
      available_at { 3.days.ago }
      expires_at { 2.days.ago }
    end

    trait :revoked do
      status { 'revoked' }
      revoked_at { 1.minute.ago }
    end
  end
end
