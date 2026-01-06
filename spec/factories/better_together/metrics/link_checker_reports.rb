# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_link_checker_report,
          class: 'BetterTogether::Metrics::LinkCheckerReport',
          aliases: %i[better_together_metrics_link_checker_report] do
    file_format { 'csv' }
    filters { {} }
  end
end
