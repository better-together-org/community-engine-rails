# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/reports/subscription_summary_report',
          class: 'BetterTogether::Billing::Reports::SubscriptionSummaryReport',
          aliases: %i[better_together_billing_subscription_summary_report] do
    association :creator, factory: :better_together_person
    file_format { 'csv' }
    filters do
      {
        from_date: 30.days.ago.to_date.to_s,
        to_date: Date.current.to_s
      }
    end
    report_data do
      {
        'summary' => {
          'active_subscription_count' => 0,
          'new_subscriptions' => 0,
          'churned_subscriptions' => 0,
          'mrr_cents' => 0
        },
        'plan_breakdown' => [],
        'event_health' => {
          'total' => 0,
          'processed' => 0,
          'pending' => 0,
          'failed' => 0,
          'dead_lettered' => 0,
          'repeated_failures' => 0
        }
      }
    end

    trait :with_data do
      report_data do
        {
          'summary' => {
            'active_subscription_count' => 3,
            'new_subscriptions' => 2,
            'churned_subscriptions' => 1,
            'mrr_cents' => 13_500,
            'date_range' => { 'from' => 30.days.ago.to_date.to_s, 'to' => Date.current.to_s }
          },
          'plan_breakdown' => [
            {
              'identifier' => 'hosted_standard_monthly',
              'name' => 'Hosted Standard',
              'billing_interval' => 'month',
              'amount_cents' => 4500,
              'currency' => 'CAD',
              'pricing_tier' => 'standard',
              'active_subscription_count' => 3,
              'mrr_contribution_cents' => 13_500
            }
          ],
          'event_health' => {
            'total' => 10,
            'processed' => 9,
            'pending' => 0,
            'failed' => 1,
            'dead_lettered' => 0,
            'repeated_failures' => 0
          }
        }
      end
    end

    trait :with_file do
      after(:create) do |report|
        report.report_file.attach(
          io: StringIO.new("Summary\nActive subscriptions,3"),
          filename: 'billing_subscription_summary.csv',
          content_type: 'text/csv'
        )
      end
    end
  end
end
