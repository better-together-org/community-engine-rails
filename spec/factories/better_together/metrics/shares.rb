# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_share, class: 'BetterTogether::Metrics::Share', aliases: [:share] do
    url { Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    platform { %w[facebook twitter linkedin email].sample }
    shared_at { Faker::Time.between(from: 15.days.ago, to: 1.day.ago) }

    trait :with_community do
      association :shareable, factory: :community
    end
  end
end
