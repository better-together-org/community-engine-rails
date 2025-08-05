# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/agreement',
          class: 'BetterTogether::Agreement',
          aliases: %i[better_together_agreement agreement] do
    id { SecureRandom.uuid }
    title { Faker::Lorem.sentence(word_count: 3) }
    slug { title.parameterize }
    privacy { 'public' }
    protected { false }
    association :creator, factory: :person
  end
end
