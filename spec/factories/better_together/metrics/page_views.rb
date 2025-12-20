# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_page_view, class: 'BetterTogether::Metrics::PageView' do
    page_url { Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    locale { I18n.available_locales.sample.to_s }
    viewed_at { Faker::Time.between(from: 15.days.ago, to: 1.day.ago) }
    pageable { nil }

    trait :with_page do
      pageable { association :page }
    end

    trait :with_event do
      pageable { association :better_together_event }
    end

    trait :with_platform do
      pageable { association :better_together_platform }
    end
  end
end
