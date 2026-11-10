# frozen_string_literal: true

module BetterTogether
  module Billing
    # The query layer behind the billing metrics reports: sales, revenue, tax collected and refunds for a platform over
    # a span of time, one summary per currency (money in two currencies is never added together) and one row per
    # month, quarter or year inside the span. Nothing is stored: every figure is read from orders, line items, tax lines,
    # payments and refunds when asked.
    #
    # * A sale counts on the day its order was paid (`paid_at`), in the platform's time zone. Orders that were never
    #   paid, or were cancelled or expired, are not sales.
    # * Revenue is the price of the lines without the tax in them, in three kinds: taxable (the line was taxed),
    #   non-taxable (its category is not taxable) and exempt (nothing was charged: no registration, an exempt registrant,
    #   a place that is not covered, a zero rate).
    # * A refund counts on the day it was recorded, and only once it succeeded or was recorded as handed back. Its tax is
    #   the pro-rated tax the refund itself carries, spread over the order's taxes by their size; the rest of it is taken
    #   from the three kinds of revenue by their size in that order.
    # * Tax is grouped by label, rate and whether it was inside the price, so HST is one row.
    #
    #   TaxReport.new(platform:, from:, to:, owner: TaxReport::Owner.all, interval: 'month').call
    # rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength, Lint/UselessConstantScoping
    class TaxReport
      SALE_STATUSES = %w[paid partially_refunded refunded].freeze
      REFUND_STATUSES = %w[succeeded recorded].freeze
      PAYMENT_STATUSES = %w[succeeded partially_refunded refunded].freeze
      INTERVALS = %w[month quarter year].freeze
      KINDS = %w[taxable non_taxable exempt].freeze
      LABEL_SQL = "COALESCE(cur.value, en.value, '')"

      TaxRow = Data.define(:label, :rate, :included, :collected_cents, :refunded_cents) do
        def net_cents = collected_cents - refunded_cents

        # "15%", "9.975%".
        def percent = "#{(BigDecimal(rate.to_s) * 100).round(3).to_s('F').sub(/\.?0+\z/, '')}%"
      end

      PaymentRow = Data.define(:processor, :payment_count, :amount_cents)

      PeriodRow = Data.define(:starts_on, :sales_count, :gross_cents, :taxable_cents, :non_taxable_cents, :exempt_cents,
                              :tax_cents, :refunded_cents, :refunded_tax_cents) do
        def revenue_cents = taxable_cents + non_taxable_cents + exempt_cents

        def net_tax_cents = tax_cents - refunded_tax_cents
      end

      Summary = Data.define(:currency, :sales_count, :gross_cents, :taxable_cents, :non_taxable_cents, :exempt_cents,
                            :refund_count, :refunded_cents, :refunded_revenue_cents, :refunded_tax_cents,
                            :tax_rows, :payments, :periods) do
        def revenue_cents = taxable_cents + non_taxable_cents + exempt_cents

        def net_revenue_cents = revenue_cents - refunded_revenue_cents

        def tax_collected_cents = tax_rows.sum(&:collected_cents)

        def net_tax_cents = tax_collected_cents - refunded_tax_cents

        def to_h = super.merge(tax_rows: tax_rows.map(&:to_h), payments: payments.map(&:to_h), periods: periods.map(&:to_h))
      end

      Result = Data.define(:from, :to, :interval, :time_zone, :summaries) do
        def currencies = summaries.map(&:currency)

        def for_currency(code) = summaries.find { |summary| summary.currency == code.to_s.upcase } || summaries.first

        def to_h
          { from: from.iso8601, to: to.iso8601, interval:, time_zone:, summaries: summaries.map(&:to_h) }
        end
      end

      def initialize(platform:, from:, to:, owner: Owner.all, interval: 'month')
        @platform = platform
        @from = from
        @to = to
        @owner = owner
        @interval = INTERVALS.include?(interval.to_s) ? interval.to_s : 'month'
      end

      def call
        currencies = (sales.keys | refunds.keys | payments.keys | tax_collected.keys).sort
        Result.new(from:, to:, interval:, time_zone: platform.time_zone, summaries: currencies.map { |code| summary_for(code) })
      end

      private

      attr_reader :platform, :from, :to, :owner, :interval

      def summary_for(code)
        sale = sales.fetch(code, {})
        refund = refunds.fetch(code, { count: 0, amount: 0, revenue: 0, tax: 0 })
        Summary.new(currency: code, sales_count: sale.fetch(:count, 0), gross_cents: sale.fetch(:gross, 0),
                    taxable_cents: sale.fetch(:taxable, 0), non_taxable_cents: sale.fetch(:non_taxable, 0),
                    exempt_cents: sale.fetch(:exempt, 0), refund_count: refund[:count], refunded_cents: refund[:amount],
                    refunded_revenue_cents: refund[:revenue], refunded_tax_cents: refund[:tax],
                    tax_rows: tax_rows_for(code), payments: payments.fetch(code, []), periods: periods_for(code))
      end

      # --- shared SQL ---------------------------------------------------------------------------------------

      def owner_sql = owner.sql

      def binds(extra = {})
        _sql, owner_binds = owner_sql
        { platform_id: platform.id, from:, to:, sales: SALE_STATUSES, locale: I18n.locale.to_s, tz: platform.time_zone,
          interval: }.merge(owner_binds).merge(extra)
      end

      def select_rows(sql, extra = {})
        query = ActiveRecord::Base.sanitize_sql_array([sql.gsub('%OWNER%', owner_sql.first), binds(extra)])
        ActiveRecord::Base.connection.select_all(query).to_a
      end

      # A line is "taxed" when it has a tax line; its base is its price without the tax inside it.
      LINE_BASE = '(li.quantity * li.unit_amount_cents - li.included_tax_cents)'
      TAXED = 'EXISTS (SELECT 1 FROM better_together_billing_tax_lines tl WHERE tl.line_item_id = li.id)'
      KIND_SQL = <<~SQL.squish
        SUM(CASE WHEN #{TAXED} THEN #{LINE_BASE} ELSE 0 END) AS taxable,
        SUM(CASE WHEN NOT #{TAXED} AND tc.taxable = FALSE THEN #{LINE_BASE} ELSE 0 END) AS non_taxable,
        SUM(CASE WHEN NOT #{TAXED} AND COALESCE(tc.taxable, TRUE) THEN #{LINE_BASE} ELSE 0 END) AS exempt
      SQL
      SALE_WHERE = <<~SQL.squish
        o.platform_id = :platform_id AND o.status IN (:sales) AND o.paid_at >= :from AND o.paid_at <= :to %OWNER%
      SQL

      # --- sales and revenue ----------------------------------------------------------------------------------

      def sales
        @sales ||= begin
          kinds = select_rows(<<~SQL.squish)
            SELECT o.currency, #{KIND_SQL}
            FROM better_together_billing_line_items li
            JOIN better_together_billing_orders o ON o.id = li.order_id AND o.platform_id = li.platform_id
            LEFT JOIN better_together_billing_tax_categories tc ON tc.id = li.tax_category_id
            WHERE #{SALE_WHERE}
            GROUP BY o.currency
          SQL
          totals = select_rows(<<~SQL.squish)
            SELECT o.currency, COUNT(*) AS sales_count, SUM(o.total_cents) AS gross
            FROM better_together_billing_orders o WHERE #{SALE_WHERE} GROUP BY o.currency
          SQL
          merge_sales(kinds, totals)
        end
      end

      def merge_sales(kinds, totals)
        result = totals.to_h { |row| [row['currency'], { count: row['sales_count'].to_i, gross: row['gross'].to_i }] }
        kinds.each do |row|
          result[row['currency']]&.merge!(taxable: row['taxable'].to_i, non_taxable: row['non_taxable'].to_i, exempt: row['exempt'].to_i)
        end
        result
      end

      # --- tax ------------------------------------------------------------------------------------------------

      LABEL_JOINS = <<~SQL.squish
        LEFT JOIN mobility_string_translations cur ON cur.translatable_type = 'BetterTogether::Billing::TaxLine'
          AND cur.translatable_id = tl.id AND cur.key = 'label' AND cur.locale = :locale
        LEFT JOIN mobility_string_translations en ON en.translatable_type = 'BetterTogether::Billing::TaxLine'
          AND en.translatable_id = tl.id AND en.key = 'label' AND en.locale = 'en'
      SQL

      def tax_collected
        @tax_collected ||= select_rows(<<~SQL.squish).group_by { |row| row['currency'] }
          SELECT o.currency, tl.rate, tl.included, #{LABEL_SQL} AS label, SUM(tl.amount_cents) AS amount
          FROM better_together_billing_tax_lines tl
          JOIN better_together_billing_orders o ON o.id = tl.order_id AND o.platform_id = tl.platform_id
          #{LABEL_JOINS}
          WHERE #{SALE_WHERE}
          GROUP BY o.currency, tl.rate, tl.included, #{LABEL_SQL}
          ORDER BY label, tl.rate
        SQL
      end

      def tax_rows_for(code)
        rows = tax_collected.fetch(code, []).to_h do |row|
          [[row['label'], BigDecimal(row['rate'].to_s), row['included']], { collected: row['amount'].to_i, refunded: 0 }]
        end
        refund_tax_by_key.fetch(code, {}).each do |key, cents|
          (rows[key] ||= { collected: 0, refunded: 0 })[:refunded] += cents
        end
        rows.sort_by { |(label, rate, _), _| [label.to_s, rate] }.map do |(label, rate, included), cents|
          TaxRow.new(label:, rate:, included:, collected_cents: cents[:collected], refunded_cents: cents[:refunded])
        end
      end

      # --- refunds --------------------------------------------------------------------------------------------

      def refund_rows
        @refund_rows ||= select_rows(<<~SQL.squish, refund_statuses: REFUND_STATUSES)
          SELECT r.id, r.amount_cents, r.tax_cents, r.created_at, o.id AS order_id, o.currency
          FROM better_together_billing_refunds r
          JOIN better_together_billing_payments p ON p.id = r.payment_id AND p.platform_id = r.platform_id
          JOIN better_together_billing_orders o ON o.id = p.order_id AND o.platform_id = p.platform_id
          WHERE o.platform_id = :platform_id AND r.status IN (:refund_statuses) AND r.created_at >= :from AND r.created_at <= :to %OWNER%
          ORDER BY r.created_at, r.id
        SQL
      end

      def refunds
        @refunds ||= refund_allocations.group_by { |entry| entry[:currency] }.transform_values do |entries|
          { count: entries.size, amount: entries.sum { |e| e[:amount] }, tax: entries.sum { |e| e[:tax] },
            revenue: entries.sum { |e| e[:revenue].values.sum } }
        end
      end

      def refund_tax_by_key
        refund_allocations.each_with_object(Hash.new { |h, k| h[k] = Hash.new(0) }) do |entry, memo|
          entry[:tax_by_key].each { |key, cents| memo[entry[:currency]][key] += cents }
        end
      end

      # One entry per refund: its tax spread over the order's taxes and its revenue over the order's three kinds.
      def refund_allocations
        @refund_allocations ||= begin
          order_ids = refund_rows.pluck('order_id').uniq
          taxes = order_taxes(order_ids)
          kinds = order_kinds(order_ids)
          refund_rows.map { |row| allocation_for(row, taxes[row['order_id']] || {}, kinds[row['order_id']] || {}) }
        end
      end

      def allocation_for(row, order_tax, order_kind)
        tax = row['tax_cents'].to_i
        net = row['amount_cents'].to_i - tax
        { currency: row['currency'], amount: row['amount_cents'].to_i, tax:, created_at: row['created_at'],
          tax_by_key: allocate(tax, order_tax), revenue: allocate(net, order_kind.presence || { 'exempt' => 1 }),
          net: }
      end

      def order_taxes(order_ids)
        return {} if order_ids.empty?

        rows = select_rows(<<~SQL.squish, order_ids:)
          SELECT tl.order_id, tl.rate, tl.included, #{LABEL_SQL} AS label, SUM(tl.amount_cents) AS amount
          FROM better_together_billing_tax_lines tl #{LABEL_JOINS}
          WHERE tl.platform_id = :platform_id AND tl.order_id IN (:order_ids)
          GROUP BY tl.order_id, tl.rate, tl.included, #{LABEL_SQL}
        SQL
        rows.group_by { |row| row['order_id'] }.transform_values do |list|
          list.to_h { |row| [[row['label'], BigDecimal(row['rate'].to_s), row['included']], row['amount'].to_i] }
        end
      end

      def order_kinds(order_ids)
        return {} if order_ids.empty?

        rows = select_rows(<<~SQL.squish, order_ids:)
          SELECT li.order_id, #{KIND_SQL}
          FROM better_together_billing_line_items li
          LEFT JOIN better_together_billing_tax_categories tc ON tc.id = li.tax_category_id
          WHERE li.platform_id = :platform_id AND li.order_id IN (:order_ids)
          GROUP BY li.order_id
        SQL
        rows.to_h { |row| [row['order_id'], KINDS.index_with { |kind| row[kind].to_i }] }
      end

      # Splits `total` over the keys in proportion to their weights, whole cents, the largest remainders taking the
      # leftover ones; the same input always gives the same split.
      def allocate(total, weights)
        sum = weights.values.sum
        return {} if total.zero? || sum.zero?

        shares = weights.map { |key, weight| [key, total * weight.to_r / sum] }
        result = shares.to_h { |key, share| [key, share.floor] }
        leftover = total - result.values.sum
        shares.sort_by { |key, share| [-(share - share.floor), key.to_s] }.first(leftover).each { |pair| result[pair.first] += 1 }
        result
      end

      # --- payment methods ------------------------------------------------------------------------------------

      def payments
        @payments ||= payment_rows.group_by { |row| row['currency'] }.transform_values do |rows|
          rows.map do |row|
            PaymentRow.new(processor: row['processor'], payment_count: row['payment_count'].to_i, amount_cents: row['amount'].to_i)
          end
        end
      end

      def payment_rows
        select_rows(<<~SQL.squish, payment_statuses: PAYMENT_STATUSES)
          SELECT o.currency, p.processor, COUNT(*) AS payment_count, SUM(p.amount_cents) AS amount
          FROM better_together_billing_payments p
          JOIN better_together_billing_orders o ON o.id = p.order_id AND o.platform_id = p.platform_id
          WHERE #{SALE_WHERE} AND p.status IN (:payment_statuses)
          GROUP BY o.currency, p.processor ORDER BY p.processor
        SQL
      end

      # --- one row per month, quarter or year ---------------------------------------------------------------------

      # Timestamps are stored in UTC without a zone: say so, then move them to the platform's zone.
      def bucket(column) = "date_trunc(:interval, (#{column} AT TIME ZONE 'UTC') AT TIME ZONE :tz)::date"

      def periods_for(code)
        buckets = period_sales.fetch(code, {}).merge(period_refunds.fetch(code, {})) { |_k, a, b| a.merge(b) }
        buckets.keys.sort.map do |day|
          row = { sales_count: 0, gross: 0, taxable: 0, non_taxable: 0, exempt: 0, tax: 0, refunded: 0, refunded_tax: 0 }.merge(buckets[day])
          PeriodRow.new(starts_on: day, sales_count: row[:sales_count], gross_cents: row[:gross], taxable_cents: row[:taxable],
                        non_taxable_cents: row[:non_taxable], exempt_cents: row[:exempt], tax_cents: row[:tax],
                        refunded_cents: row[:refunded], refunded_tax_cents: row[:refunded_tax])
        end
      end

      def period_sales
        @period_sales ||= begin
          kinds = select_rows(<<~SQL.squish)
            SELECT o.currency, #{bucket('o.paid_at')} AS day, #{KIND_SQL}
            FROM better_together_billing_line_items li
            JOIN better_together_billing_orders o ON o.id = li.order_id AND o.platform_id = li.platform_id
            LEFT JOIN better_together_billing_tax_categories tc ON tc.id = li.tax_category_id
            WHERE #{SALE_WHERE} GROUP BY o.currency, day
          SQL
          totals = select_rows(<<~SQL.squish)
            SELECT o.currency, #{bucket('o.paid_at')} AS day, COUNT(*) AS sales_count, SUM(o.total_cents) AS gross, SUM(o.tax_cents) AS tax
            FROM better_together_billing_orders o WHERE #{SALE_WHERE} GROUP BY o.currency, day
          SQL
          index_periods(kinds, totals)
        end
      end

      def index_periods(kinds, totals)
        result = Hash.new { |h, k| h[k] = {} }
        totals.each do |row|
          result[row['currency']][row['day'].to_date] = { sales_count: row['sales_count'].to_i, gross: row['gross'].to_i, tax: row['tax'].to_i }
        end
        kinds.each do |row|
          result[row['currency']][row['day'].to_date]&.merge!(taxable: row['taxable'].to_i, non_taxable: row['non_taxable'].to_i,
                                                              exempt: row['exempt'].to_i)
        end
        result
      end

      # Refunds fall in the period they were recorded in; the zone's day boundaries are used by the same expression.
      def period_refunds
        @period_refunds ||= begin
          result = Hash.new { |h, k| h[k] = {} }
          refund_allocations.each do |entry|
            day = bucket_day(entry[:created_at])
            slot = (result[entry[:currency]][day] ||= { refunded: 0, refunded_tax: 0 })
            slot[:refunded] += entry[:amount]
            slot[:refunded_tax] += entry[:tax]
          end
          result
        end
      end

      def bucket_day(time)
        local = Time.zone.parse(time.to_s).in_time_zone(platform.time_zone)
        case interval
        when 'year' then local.beginning_of_year.to_date
        when 'quarter' then local.beginning_of_quarter.to_date
        else local.beginning_of_month.to_date
        end
      end
    end
    # rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength, Lint/UselessConstantScoping
  end
end
