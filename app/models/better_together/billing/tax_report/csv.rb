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
            csv << ['Report', 'Billing', 'From', @data['from'], 'To', @data['to'], 'By', @data['interval'], 'Basis', @data['basis'],
                    'Time zone', @data['time_zone']]
            @data['summaries'].each { |summary| write_currency(csv, summary) }
          end
        end

        private

        def write_currency(csv, summary)
          code = summary['currency']
          csv << []
          csv << ['Currency', code]
          write_summary(csv, summary, code)
          write_return(csv, summary, code)
          write_tax(csv, summary, code)
          write_regions(csv, summary, code)
          write_payments(csv, summary, code)
          write_periods(csv, summary, code)
        end

        def write_summary(csv, summary, code) # rubocop:disable Metrics/AbcSize
          csv << %w[Summary Amount]
          csv << ['Sales', summary['sales_count']]
          csv << ['Gross sales (with tax)', money(summary['gross_cents'], code)]
          %w[taxable zero_rated non_taxable exempt].each do |kind|
            csv << ["Revenue: #{kind.tr('_', ' ')}", money(summary["#{kind}_cents"], code)]
          end
          csv << ['Refunds', summary['refund_count']]
          csv << ['Refunded (with tax)', money(summary['refunded_cents'], code)]
          csv << ['Refunded revenue', money(summary['refunded_revenue_cents'], code)]
          csv << ['Refunded tax', money(summary['refunded_tax_cents'], code)]
        end

        # The lines a GST/HST return asks for, then what each other tax is owed to its own administrator.
        def write_return(csv, summary, code)
          csv << []
          csv << %w[Return Amount]
          csv << ['Total revenue (without tax)', money(revenue(summary), code)]
          csv << ['Zero-rated supplies', money(summary['zero_rated_cents'], code)]
          (summary['authorities'] || []).each do |row|
            csv << ["Tax owed: #{row['authority']}", money(row['collected_cents'] - row['refunded_cents'], code)]
          end
        end

        def write_regions(csv, summary, code)
          csv << []
          csv << %w[Region Sales Gross Tax]
          (summary['regions'] || []).each do |row|
            csv << [safe(row['region_code']), row['sales_count'], money(row['gross_cents'], code), money(row['tax_cents'], code)]
          end
          write_registrations(csv, summary)
        end

        def write_registrations(csv, summary)
          csv << []
          csv << ['Registration', 'Region', 'Status', 'Collected by', 'Number']
          (summary['registrations'] || []).each do |row|
            csv << [row['country_iso'], safe(row['region_code']), row['status'], row['collected_by'], safe(row['masked_number'])]
          end
        end

        def revenue(summary) = %w[taxable zero_rated non_taxable exempt].sum { |kind| summary["#{kind}_cents"] }

        def write_tax(csv, summary, code) # rubocop:disable Metrics/AbcSize
          csv << []
          csv << ['Tax', 'Rate', 'Administrator', 'Collected by', 'Inside the price', 'Collected', 'Refunded', 'Net']
          summary['tax_rows'].each do |row|
            csv << [safe(row['label']), percent(row['rate']), row['authority'], row['collected_by'], row['included'] ? 'yes' : 'no',
                    money(row['collected_cents'], code), money(row['refunded_cents'], code),
                    money(row['collected_cents'] - row['refunded_cents'], code)]
          end
        end

        def write_payments(csv, summary, code)
          csv << []
          csv << ['Payment method', 'Payments', 'Amount']
          summary['payments'].each { |row| csv << [safe(row['processor']), row['payment_count'], money(row['amount_cents'], code)] }
        end

        def write_periods(csv, summary, code)
          csv << []
          csv << ['Period starting', 'Sales', 'Gross', 'Taxable', 'Zero-rated', 'Non-taxable', 'Exempt', 'Tax collected', 'Refunded',
                  'Refunded tax']
          summary['periods'].each do |row|
            csv << [row['starts_on'], row['sales_count'], *%w[gross taxable zero_rated non_taxable exempt tax refunded refunded_tax].map do |key|
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
