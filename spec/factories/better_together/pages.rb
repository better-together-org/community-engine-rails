# frozen_string_literal: true

# spec/factories/pages.rb

FactoryBot.define do
  factory :better_together_page,
          class: 'BetterTogether::Page',
          aliases: %i[page] do
    bt_id { SecureRandom.uuid }
    title { Faker::Lorem.sentence(word_count: 3) }
    slug { title.parameterize }
    content { Faker::Lorem.paragraph }
    meta_description { Faker::Lorem.sentence }
    keywords { Faker::Lorem.words(number: 4).join(', ') }
    published { Faker::Boolean.boolean }
    published_at { Faker::Date.backward(days: 30) }
    privacy { BetterTogether::Page::PRIVACY_LEVELS.keys.sample.to_s }
    layout { Faker::Lorem.word }
    template { Faker::Lorem.word }
    language { 'en' }
    protected { Faker::Boolean.boolean }
  end
end
