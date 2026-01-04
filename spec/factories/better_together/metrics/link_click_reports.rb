# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_link_click_report,
          class: 'BetterTogether::Metrics::LinkClickReport',
          aliases: %i[better_together_metrics_link_click_report] do
    file_format { 'csv' }
    filters { {} }
  end
end
