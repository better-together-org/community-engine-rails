# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/offer', class: 'BetterTogether::Joatu::Offer',
                                         aliases: %i[better_together_joatu_offer joatu_offer offer] do
    id { SecureRandom.uuid }
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.paragraph }
    creator { association :better_together_person }

    trait :with_target do
      target { association :better_together_person }
    end

    trait :with_target_type do
      target_type { 'BetterTogether::Invitation' }
    end

    # Ensure a persisted category and in-memory association are set before validation
    after(:build) do |offer|
      next unless offer.categories.blank? && offer.categorizations.blank?

      category = create(:better_together_joatu_category)
      offer.categories << category
    end
  end
end
