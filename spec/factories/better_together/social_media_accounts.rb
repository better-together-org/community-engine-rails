# frozen_string_literal: true

FactoryBot.define do
  factory :social_media_account, class: 'BetterTogether::SocialMediaAccount' do
    contact_detail { association :contact_detail }
    platform { 'Facebook' }
    handle { Faker::Internet.username(specifier: 5..15, separators: %w[.]) }
    privacy { 'public' }

    trait :instagram do
      platform { 'Instagram' }
    end

    trait :linkedin do
      platform { 'LinkedIn' }
    end

    trait :youtube do
      platform { 'YouTube' }
    end

    trait :tiktok do
      platform { 'TikTok' }
    end

    trait :reddit do
      platform { 'Reddit' }
    end

    trait :with_url do
      url { Faker::Internet.url }
    end

    trait :with_at_handle do
      handle { "@#{Faker::Internet.username(specifier: 5..15, separators: %w[.])}" }
    end

    trait :private do
      privacy { 'private' }
    end
  end
end
