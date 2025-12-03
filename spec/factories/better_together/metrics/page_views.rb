# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_page_view, class: 'BetterTogether::Metrics::PageView' do
    viewed_at { Time.current }
    locale { I18n.default_locale.to_s }
    page_url { '/test-page' }

    trait :with_pageable do
      association :pageable, factory: :page
      page_url { nil } # Let the model generate it from pageable
    end
  end
end
