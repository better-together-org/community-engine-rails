# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/c3/balance', class: 'BetterTogether::C3::Balance',
                                        aliases: %i[c3_balance] do
    association :holder, factory: :better_together_person
    available_millitokens { 0 }
    locked_millitokens { 0 }
    lifetime_earned_millitokens { 0 }

    trait :with_funds do
      available_millitokens { 10_000 }
      lifetime_earned_millitokens { 10_000 }
    end

    trait :federated do
      association :origin_platform, factory: :better_together_platform
    end
  end
end
