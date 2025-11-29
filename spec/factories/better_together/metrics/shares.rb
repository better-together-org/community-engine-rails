# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_share, class: 'BetterTogether::Metrics::Share', aliases: [:share] do
    platform { 'facebook' }
    url { 'https://facebook.com/share/12345' }
    shared_at { Time.current }
    locale { 'en' }

    trait :with_community do
      association :shareable, factory: :community
    end
  end
end
