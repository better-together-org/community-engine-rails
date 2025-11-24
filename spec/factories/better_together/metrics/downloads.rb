# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_download, class: 'BetterTogether::Metrics::Download', aliases: [:download] do
    file_name { 'document.pdf' }
    file_type { 'application/pdf' }
    file_size { 1024 }
    downloaded_at { Time.current }
    locale { 'en' }

    trait :with_community do
      association :downloadable, factory: :community
    end
  end
end
