# frozen_string_literal: true

FactoryBot.define do
  factory :website_link, class: 'BetterTogether::WebsiteLink' do
    contact_detail { association :contact_detail }
    url { Faker::Internet.url }
    label { 'personal_website' }
    privacy { 'public' }

    trait :blog do
      label { 'blog' }
    end

    trait :portfolio do
      label { 'portfolio' }
    end

    trait :company_website do
      label { 'company_website' }
    end

    trait :community_page do
      label { 'community_page' }
    end

    trait :documentation do
      label { 'documentation' }
    end

    trait :private do
      privacy { 'private' }
    end

    trait :https do
      url { "https://#{Faker::Internet.domain_name}" }
    end

    trait :http do
      url { "http://#{Faker::Internet.domain_name}" }
    end
  end
end
