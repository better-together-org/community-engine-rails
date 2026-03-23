# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_page_view, class: 'BetterTogether::Metrics::PageView' do
    transient do
      skip_page_url { false }
    end

    # Only set page_url if not skipped (when pageable is provided, let model callback handle it)
    page_url { skip_page_url ? nil : Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    locale { I18n.available_locales.sample.to_s }
    viewed_at { Faker::Time.between(from: 15.days.ago, to: 1.day.ago) }
    pageable { nil }

    # Override to skip page_url when pageable is provided
    after(:build) do |page_view, evaluator|
      page_view.page_url = nil if page_view.pageable.present? && !evaluator.skip_page_url
    end

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
