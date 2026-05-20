# frozen_string_literal: true

module BetterTogether
  module Billing
    module Reports
      # Generates aggregate reports on billing subscription activity.
      # Covers active subscriptions, MRR, plan breakdown by pricing tier,
      # and webhook event processing health for a given date range.
      # rubocop:disable Metrics/ClassLength
      class SubscriptionSummaryReport < ApplicationRecord
        self.table_name = 'better_together_billing_subscription_summary_reports'

        belongs_to :creator,
                   class_name: 'BetterTogether::Person',
                   foreign_key: 'creator_id',
                   inverse_of: :billing_subscription_summary_reports,
                   optional: true

        has_one_attached :report_file, dependent: :purge_later

        validates :filters, presence: true
        validates :file_format, presence: true, inclusion: { in: %w[csv] }

        default_scope { order(created_at: :desc) }

        def self.create_and_generate!(creator:, from_date: nil, to_date: nil, file_format: 'csv')
          report = create!(
            filters: { from_date: from_date, to_date: to_date }.compact,
            file_format: file_format,
            creator: creator
          )
          report.generate!
          report
        end

        def generate!
          self.report_data = build_report_data
          save!
          GenerateSubscriptionSummaryReportJob.perform_later(id)
        end

        private

        def build_report_data
          date_range = parse_date_range

          {
            summary: build_summary(date_range),
            plan_breakdown: build_plan_breakdown,
            event_health: build_event_health(date_range),
            generated_at: Time.current.iso8601
          }
        end

        def parse_date_range
          from_date = filters['from_date']&.to_date || 30.days.ago.to_date
          to_date   = filters['to_date']&.to_date   || Date.current
          from_date.beginning_of_day..to_date.end_of_day
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def build_summary(date_range)
          active_count = BetterTogether::Billing::Subscription
                         .joins(:pay_subscription)
                         .merge(Pay::Subscription.active)
                         .count

          new_count = BetterTogether::Billing::Subscription
                      .where(created_at: date_range)
                      .count

          churned_count = BetterTogether::Billing::Subscription
                          .joins(:pay_subscription)
                          .where(pay_subscriptions: { status: 'canceled', ends_at: date_range })
                          .count

          {
            active_subscription_count: active_count,
            new_subscriptions: new_count,
            churned_subscriptions: churned_count,
            current_mrr_cents: calculate_mrr_cents,
            date_range: {
              from: date_range.begin.to_date.iso8601,
              to: date_range.end.to_date.iso8601
            }
          }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def calculate_mrr_cents
          plans = BetterTogether::Billing::Plan.arel_table

          monthly = BetterTogether::Billing::Subscription
                    .joins(:pay_subscription, :billing_plan)
                    .merge(Pay::Subscription.active)
                    .where(better_together_billing_plans: { billing_interval: 'month' })
                    .sum(plans[:amount_cents])

          yearly = BetterTogether::Billing::Subscription
                   .joins(:pay_subscription, :billing_plan)
                   .merge(Pay::Subscription.active)
                   .where(better_together_billing_plans: { billing_interval: 'year' })
                   .sum(plans[:amount_cents])

          monthly + (yearly / 12.0).round
        end

        # rubocop:disable Metrics/MethodLength
        def build_plan_breakdown
          active_counts = BetterTogether::Billing::Subscription
                          .joins(:pay_subscription)
                          .merge(Pay::Subscription.active)
                          .group(:billing_plan_id)
                          .count

          BetterTogether::Billing::Plan.order(:identifier).map do |plan|
            active_for_plan = active_counts.fetch(plan.id, 0)

            {
              identifier: plan.identifier,
              name: plan.name,
              billing_interval: plan.billing_interval,
              amount_cents: plan.amount_cents,
              currency: plan.currency,
              pricing_tier: plan.pricing_tier,
              active_subscription_count: active_for_plan,
              mrr_contribution_cents: mrr_contribution_for(plan, active_for_plan)
            }
          end
        end
        # rubocop:enable Metrics/MethodLength

        def mrr_contribution_for(plan, active_count)
          return 0 unless plan.recurring?

          monthly_rate = plan.billing_interval == 'year' ? (plan.amount_cents / 12.0).round : plan.amount_cents
          monthly_rate * active_count
        end

        def build_event_health(date_range)
          events = BetterTogether::Billing::Event.where(created_at: date_range)

          {
            total: events.count,
            processed: events.where(processing_status: 'processed').count,
            pending: events.pending.count,
            failed: events.failed.count,
            dead_lettered: events.dead_lettered.count,
            repeated_failures: events.repeated_failures.count
          }
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
