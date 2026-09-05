# frozen_string_literal: true

FactoryBot.define do
  factory :call_for_interest, class: 'BetterTogether::CallForInterest' do
    sequence(:identifier) { |n| "call_for_interest_#{n}" }
    name { Faker::Company.catch_phrase }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    privacy { 'public' }
    association :creator, factory: :person
    # Explicitly :public — the base platform factory defaults to 'private',
    # which would make this record's own 'public' privacy default exceed the
    # platform's privacy ceiling (see PrivacyCeilingValidatable).
    association :platform, factory: %i[better_together_platform public]
    starts_at { 1.week.from_now }
    ends_at { 2.weeks.from_now }

    trait :with_event do
      association :interestable, factory: :event
    end

    trait :draft do
      starts_at { nil }
      ends_at { nil }
    end

    trait :past do
      starts_at { 2.weeks.ago }
      ends_at { 1.week.ago }
    end

    trait :upcoming do
      starts_at { 1.week.from_now }
      ends_at { 2.weeks.from_now }
    end

    trait :private do
      privacy { 'private' }
    end
  end
end
