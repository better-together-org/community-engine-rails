# frozen_string_literal: true

module BetterTogether
  module Billing
    class TaxReport
      # A report in the shapes the metrics charts take: `{ labels:, datasets: }` for a stacked chart and
      # `{ labels:, values: }` for a plain one. One currency at a time, in that currency's units (never cents).
      class ChartData
        COLORS = {
          taxable: [54, 162, 235], zero_rated: [75, 192, 120], non_taxable: [255, 206, 86], exempt: [153, 102, 255],
          tax: [75, 192, 192], refunded: [255, 99, 132]
        }.freeze

        def initialize(result, currency)
          @result = result
          @summary = result.for_currency(currency)
        end

        def revenue
          return { labels: [], datasets: [] } unless summary

          { labels: summary.periods.map { |period| label_for(period.starts_on) }, datasets: datasets }
        end

        def tax_by_rate
          return { labels: [], values: [] } unless summary

          { labels: summary.tax_rows.map { |row| "#{row.label} #{row.percent}" },
            values: summary.tax_rows.map { |row| major(row.net_cents) } }
        end

        private

        attr_reader :result, :summary

        def datasets
          [dataset(:taxable, &:taxable_cents), dataset(:zero_rated, &:zero_rated_cents),
           dataset(:non_taxable, &:non_taxable_cents), dataset(:exempt, &:exempt_cents),
           dataset(:tax) { |period| period.tax_cents - period.refunded_tax_cents },
           dataset(:refunded) { |period| -(period.refunded_cents - period.refunded_tax_cents) }]
        end

        def dataset(kind, &)
          red, green, blue = COLORS.fetch(kind)
          { label: I18n.t("better_together.metrics.reports.charts.billing_#{kind}"), backgroundColor: "rgba(#{red}, #{green}, #{blue}, 0.5)",
            borderColor: "rgba(#{red}, #{green}, #{blue}, 1)", data: summary.periods.map { |period| major(yield(period)) } }
        end

        def major(cents) = Currency.to_major(cents, summary.currency)

        def label_for(day)
          case result.interval
          when 'year' then day.year.to_s
          when 'quarter' then "#{day.year} Q#{((day.month - 1) / 3) + 1}"
          else day.strftime('%Y-%m')
          end
        end
      end
    end
  end
end
