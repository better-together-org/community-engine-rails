FactoryBot.define do
  factory :better_together_post, class: 'BetterTogether::Post', aliases: %i[authorable] do
    bt_id { Faker::Internet.uuid }
    title { 'My title'}
    content { 'My content'}

    trait :draft do
      published_at { nil }
    end

    trait :published do
      published_at { DateTime.current - 1.day }
    end

    trait :scheduled do
      published_at { DateTime.current + 1.day }
    end
  end
end
