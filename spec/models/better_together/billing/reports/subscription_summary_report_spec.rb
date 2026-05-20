# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    module Reports
      RSpec.describe SubscriptionSummaryReport do
        include ActiveJob::TestHelper

        subject(:report) do
          described_class.new(
            filters: { from_date: 30.days.ago.to_date.to_s, to_date: Date.current.to_s }
          )
        end

        describe 'associations' do
          it { is_expected.to have_one_attached(:report_file) }
        end

        describe 'validations' do
          it { is_expected.to validate_inclusion_of(:file_format).in_array(%w[csv]) }
        end

        describe '#generate!' do
          it 'builds report data and saves the record' do
            expect { report.generate! }.to change(described_class, :count).by(1)
            expect(report.report_data).to be_present
            expect(report.report_data['summary']).to be_present
            expect(report.report_data['plan_breakdown']).to be_present
            expect(report.report_data['event_health']).to be_present
          end

          it 'enqueues the CSV generation job' do
            report.save!
            expect { report.generate! }.to have_enqueued_job(GenerateSubscriptionSummaryReportJob)
              .with(report.id)
          end
        end

        describe '#build_summary (via generate!)' do
          let(:community) { create(:better_together_community) }
          let(:plan) do
            create('better_together/billing/plan',
                   amount_cents: 4500,
                   billing_interval: 'month',
                   currency: 'CAD')
          end
          let(:pay_customer) do
            Pay::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_rpt_test')
          end
          let(:pay_sub) do
            Pay::Subscription.create!(
              customer: pay_customer,
              name: 'default',
              processor_id: 'sub_rpt_test',
              processor_plan: plan.stripe_price_id,
              status: 'active',
              current_period_start: Time.current.beginning_of_day,
              current_period_end: 1.month.from_now.beginning_of_day
            )
          end

          before do
            BetterTogether::Billing::Subscription.create!(
              pay_subscription: pay_sub,
              billing_plan: plan
            )
            report.generate!
          end

          it 'counts active subscriptions' do
            expect(report.report_data['summary']['active_subscription_count']).to eq(1)
          end

          it 'calculates MRR in cents' do
            expect(report.report_data['summary']['mrr_cents']).to eq(4500)
          end
        end

        describe '#build_plan_breakdown (via generate!)' do
          let(:plan) do
            create('better_together/billing/plan',
                   identifier: 'hosted_test_monthly',
                   amount_cents: 4500,
                   billing_interval: 'month')
          end

          before do
            plan
            report.generate!
          end

          it 'includes an entry for each plan' do
            identifiers = report.report_data['plan_breakdown'].map { |r| r['identifier'] }
            expect(identifiers).to include('hosted_test_monthly')
          end

          it 'includes pricing_tier in each plan row' do
            row = report.report_data['plan_breakdown'].find { |r| r['identifier'] == 'hosted_test_monthly' }
            expect(row['pricing_tier']).to eq('standard')
          end
        end

        describe '#build_event_health (via generate!)' do
          before do
            create('better_together/billing/event', processing_status: 'processed',
                                                    created_at: 1.day.ago)
            create('better_together/billing/event', processing_status: 'failed',
                                                    created_at: 1.day.ago)
            report.generate!
          end

          it 'counts events by processing status' do
            health = report.report_data['event_health']
            expect(health['processed']).to eq(1)
            expect(health['failed']).to eq(1)
          end
        end
      end
    end
  end
end
