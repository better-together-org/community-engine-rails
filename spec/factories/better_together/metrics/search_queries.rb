# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_search_query, class: 'Metrics::SearchQuery' do
    query { 'test query' }
    results_count { 1 }
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    locale { 'en' }
    logged_in { false }
    searched_at { Time.zone.now }
  end
end
