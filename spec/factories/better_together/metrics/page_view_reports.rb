# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_page_view_report, class: 'BetterTogether::Metrics::PageViewReport' do
    file_format { 'csv' }
    sort_by_total_views { false }
    filters { {} }
  end
end
