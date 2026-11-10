# frozen_string_literal: true

require 'csv'

module BetterTogether
  module Billing
    class TaxReport
      # The CSV of a report, built from the figures a Metrics::BillingReport stored (string keys). Amounts are decimal
      # in the currency's own units. Text that came from people (a tax label, a payment method) never starts with a
      # character a spreadsheet would run as a formula.
      class Csv
        def self.generate(data) = new(data).generate

        def initialize(data)
          @data = data
        end

        def generate
          CSV.generate do |csv|
            csv << ['Report', 'Billing', 'From', @data['from'], 'To', @data['to'], 'By', @data['interval'], 'Time zone', @data['time_zone']]
            @data['summaries'].each { |summary| write_currency(csv, summary) }
          end
        end

        private

        def write_currency(csv, summary)
          code = summary['currency']
          csv << []
          csv << ['Currency', code]
          write_summary(csv, summary, code)
          write_tax(csv, summary, code)
          write_payments(csv, summary, code)
          write_periods(csv, summary, code)
        end

        def write_summary(csv, summary, code) # rubocop:disable Metrics/AbcSize
          csv << %w[Summary Amount]
          csv << ['Sales', summary['sales_count']]
          csv << ['Gross sales (with tax)', money(summary['gross_cents'], code)]
          %w[taxable non_taxable exempt].each { |kind| csv << ["Revenue: #{kind.tr('_', ' ')}", money(summary["#{kind}_cents"], code)] }
          csv << ['Refunds', summary['refund_count']]
          csv << ['Refunded (with tax)', money(summary['refunded_cents'], code)]
          csv << ['Refunded revenue', money(summary['refunded_revenue_cents'], code)]
          csv << ['Refunded tax', money(summary['refunded_tax_cents'], code)]
        end

        def write_tax(csv, summary, code) # rubocop:disable Metrics/AbcSize
          csv << []
          csv << ['Tax', 'Rate', 'Inside the price', 'Collected', 'Refunded', 'Net']
          summary['tax_rows'].each do |row|
            csv << [safe(row['label']), percent(row['rate']), row['included'] ? 'yes' : 'no', money(row['collected_cents'], code),
                    money(row['refunded_cents'], code), money(row['collected_cents'] - row['refunded_cents'], code)]
          end
        end

        def write_payments(csv, summary, code)
          csv << []
          csv << ['Payment method', 'Payments', 'Amount']
          summary['payments'].each { |row| csv << [safe(row['processor']), row['payment_count'], money(row['amount_cents'], code)] }
        end

        def write_periods(csv, summary, code)
          csv << []
          csv << ['Period starting', 'Sales', 'Gross', 'Taxable', 'Non-taxable', 'Exempt', 'Tax collected', 'Refunded', 'Refunded tax']
          summary['periods'].each do |row|
            csv << [row['starts_on'], row['sales_count'], *%w[gross taxable non_taxable exempt tax refunded refunded_tax].map do |key|
              money(row["#{key}_cents"], code)
            end]
          end
        end

        def money(cents, code) = format("%.#{Currency.exponent(code)}f", Currency.to_major(cents, code))

        def percent(rate) = "#{(BigDecimal(rate.to_s) * 100).round(3).to_s('F').sub(/\.?0+\z/, '')}%"

        def safe(text) = text.to_s.match?(/\A[=+\-@\t\r]/) ? "'#{text}" : text.to_s
      end
    end
  end
end
