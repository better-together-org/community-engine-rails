# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_search_query, class: 'Metrics::SearchQuery' do
    query { 'test query' }
    results_count { 1 }
    locale { 'en' }
    searched_at { Time.zone.now }
  end
end
