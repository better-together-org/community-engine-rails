# frozen_string_literal: true

module BetterTogether
  module Metrics
    # A saved billing report: sales, revenue, tax collected and refunds for a span, by month, quarter or year, for one
    # owner or all of them. Like the other metrics reports it keeps the filters it was asked with and the figures as
    # they were, and a CSV file is attached by GenerateBillingReportJob. The figures come from Billing::TaxReport.
    class BillingReport < PlatformRecord
      belongs_to :creator, class_name: 'BetterTogether::Person', foreign_key: 'creator_id', inverse_of: :billing_reports, optional: true

      has_one_attached :report_file, dependent: :purge_later

      validates :filters, presence: true
      validates :file_format, presence: true, inclusion: { in: %w[csv] }

      default_scope { order(created_at: :desc) }

      # Dates are whole days in the platform's time zone; an owner is "all", "platform" or "Type:id".
      def self.create_and_generate!( # rubocop:disable Metrics/ParameterLists
        creator:, platform:, from_date: nil, to_date: nil, owner: 'all', interval: 'month', file_format: 'csv'
      )
        today = Time.current.in_time_zone(ActiveSupport::TimeZone[platform.time_zone || 'UTC']).to_date
        report = create!(
          filters: { from_date: from_date.presence || (today - 30).to_s, to_date: to_date.presence || today.to_s,
                     owner: owner.presence || 'all', interval: interval.presence || 'month' },
          file_format:, creator:, platform:
        )
        report.generate!
        report
      end

      def generate!
        self.report_data = build_report_data
        save!
        GenerateBillingReportJob.perform_later(id)
      end

      def filter(key) = filters.with_indifferent_access[key]

      def time_zone = platform&.time_zone || 'UTC'

      def starts_at
        zone = ActiveSupport::TimeZone[time_zone]
        (filter('from_date')&.to_date || 30.days.ago.to_date).in_time_zone(zone).beginning_of_day
      end

      def ends_at
        zone = ActiveSupport::TimeZone[time_zone]
        (filter('to_date')&.to_date || Time.current.in_time_zone(zone).to_date).in_time_zone(zone).end_of_day
      end

      private

      def build_report_data
        Billing::TaxReport.new(platform:, from: starts_at, to: ends_at, owner: Billing::TaxReport::Owner.parse(filter('owner')),
                               interval: filter('interval')).call.to_h.deep_stringify_keys.merge('generated_at' => Time.current.iso8601)
      end
    end
  end
end
