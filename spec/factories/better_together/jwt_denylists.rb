# frozen_string_literal: true

FactoryBot.define do
  factory :jwt_denylist, class: 'BetterTogether::JwtDenylist' do
    jti { SecureRandom.uuid }
    exp { 1.hour.from_now }

    trait :expired do
      exp { 1.hour.ago }
    end

    trait :recently_expired do
      exp { 5.minutes.ago }
    end

    trait :expires_soon do
      exp { 5.minutes.from_now }
    end

    trait :long_lived do
      exp { 1.week.from_now }
    end
  end
end
