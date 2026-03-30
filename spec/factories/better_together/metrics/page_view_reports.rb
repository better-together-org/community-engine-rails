# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_page_view_report,
          class: 'BetterTogether::Metrics::PageViewReport',
          aliases: %i[better_together_metrics_page_view_report] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    file_format { 'csv' }
    sort_by_total_views { false }
    filters { {} }
  end
end
