# frozen_string_literal: true

module BetterTogether
  module Billing
    # The query layer behind the billing metrics reports: sales, revenue, tax collected and refunds for a platform over
    # a span of time, one summary per currency (money in two currencies is never added together) and one row per
    # month, quarter or year inside the span. Nothing is stored: every figure is read from orders, line items, tax lines,
    # payments and refunds when asked, with Arel and association joins (no SQL strings).
    #
    # * Dates are read in the platform's time zone. Orders that were never paid, or were cancelled or expired, are not sales.
    # * A sale counts on the day its order was paid (the default) or on the day it was invoiced (`placed_at`), which is the
    #   day a GST/HST return counts it on; either way only orders that were paid are included.
    # * Revenue is the price of the lines without the tax in them, in four kinds: taxable (the line was taxed), zero-rated
    #   (an untaxed line in a zero-rated category, which a GST/HST return reports apart), non-taxable (any other category
    #   that is not taxable, such as an exempt supply) and exempt (nothing was charged: no registration, an exempt
    #   registrant, a place that is not covered, a zero rate).
    # * A refund counts on the day it was recorded, and only once it succeeded or was recorded as handed back. Its tax is
    #   the pro-rated tax the refund itself carries, spread over the order's taxes by their size; the rest of it is taken
    #   from the three kinds of revenue by their size in that order.
    # * Tax is grouped by label, rate, whether it was inside the price, the tax it is filed under (authority) and who
    #   collected it: the seller (its own registration), the platform (its own sale) or the platform for a seller's sale
    #   (a facilitator, whose tax is not on the seller's return).
    #
    #   TaxReport.new(platform:, from:, to:, owner: TaxReport::Owner.all, interval: 'month').call
    # rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength
    class TaxReport
      SALE_STATUSES = %w[paid partially_refunded refunded].freeze
      REFUND_STATUSES = %w[succeeded recorded].freeze
      PAYMENT_STATUSES = %w[succeeded partially_refunded refunded].freeze
      INTERVALS = %w[month quarter year].freeze
      BASES = %w[paid invoice].freeze
      KINDS = %w[taxable zero_rated non_taxable exempt].freeze
      ZERO_RATED_CATEGORIES = %w[zero_rated basic_groceries].freeze
      AUTHORITIES = TaxRate::AUTHORITIES

      TaxRow = Data.define(:label, :rate, :included, :authority, :collected_by, :collected_cents, :refunded_cents) do
        def net_cents = collected_cents - refunded_cents

        # "15%", "9.975%".
        def percent = "#{(BigDecimal(rate.to_s) * 100).round(3).to_s('F').sub(/\.?0+\z/, '')}%"
      end

      PaymentRow = Data.define(:processor, :payment_count, :amount_cents)

      AuthorityRow = Data.define(:authority, :collected_cents, :refunded_cents) do
        def net_cents = collected_cents - refunded_cents
      end

      RegionRow = Data.define(:region_code, :sales_count, :gross_cents, :tax_cents)

      # A registration an order was taxed under. The number is masked: reports are stored, and the number is not.
      RegistrationRow = Data.define(:country_iso, :region_code, :status, :collected_by, :masked_number)

      RefundRow = Data.define(:id, :amount_cents, :tax_cents, :created_at, :order_id, :currency)

      PeriodRow = Data.define(:starts_on, :sales_count, :gross_cents, :taxable_cents, :zero_rated_cents, :non_taxable_cents,
                              :exempt_cents, :tax_cents, :refunded_cents, :refunded_tax_cents) do
        def revenue_cents = taxable_cents + zero_rated_cents + non_taxable_cents + exempt_cents

        def net_tax_cents = tax_cents - refunded_tax_cents
      end

      Summary = Data.define(:currency, :sales_count, :gross_cents, :taxable_cents, :zero_rated_cents, :non_taxable_cents,
                            :exempt_cents, :refund_count, :refunded_cents, :refunded_revenue_cents, :refunded_tax_cents,
                            :tax_rows, :payments, :periods, :regions, :registrations) do
        def revenue_cents = taxable_cents + zero_rated_cents + non_taxable_cents + exempt_cents

        def net_revenue_cents = revenue_cents - refunded_revenue_cents

        def tax_collected_cents = tax_rows.sum(&:collected_cents)

        def net_tax_cents = tax_collected_cents - refunded_tax_cents

        # Tax per authority, in the order of AUTHORITIES: what each return or administrator is owed.
        def authority_rows
          grouped = tax_rows.group_by(&:authority).map do |authority, rows|
            AuthorityRow.new(authority:, collected_cents: rows.sum(&:collected_cents), refunded_cents: rows.sum(&:refunded_cents))
          end
          grouped.sort_by { |row| AUTHORITIES.index(row.authority) || AUTHORITIES.size }
        end

        def to_h
          super.merge(tax_rows: tax_rows.map(&:to_h), payments: payments.map(&:to_h), periods: periods.map(&:to_h),
                      regions: regions.map(&:to_h), registrations: registrations.map(&:to_h), authorities: authority_rows.map(&:to_h))
        end
      end

      Result = Data.define(:from, :to, :interval, :basis, :time_zone, :summaries) do
        def currencies = summaries.map(&:currency)

        # A blank code means the first summary; an explicit code with no activity gets nil, never another currency.
        def for_currency(code)
          return summaries.first if code.blank?

          summaries.find { |summary| summary.currency == code.to_s.upcase }
        end

        def to_h
          { from: from.iso8601, to: to.iso8601, interval:, basis:, time_zone:, summaries: summaries.map(&:to_h) }
        end
      end

      def initialize(platform:, from:, to:, owner: Owner.all, interval: 'month', basis: 'paid') # rubocop:disable Metrics/ParameterLists
        @platform = platform
        @from = from
        @to = to
        @owner = owner
        @interval = INTERVALS.include?(interval.to_s) ? interval.to_s : 'month'
        @basis = BASES.include?(basis.to_s) ? basis.to_s : 'paid'
      end

      def call
        currencies = (sales.keys | refunds.keys | payments.keys | tax_collected.keys).sort
        Result.new(from:, to:, interval:, basis:, time_zone: platform.time_zone, summaries: currencies.map { |code| summary_for(code) })
      end

      private

      attr_reader :platform, :from, :to, :owner, :interval, :basis

      def summary_for(code)
        sale = sales.fetch(code, {})
        refund = refunds.fetch(code, { count: 0, amount: 0, revenue: 0, tax: 0 })
        Summary.new(currency: code, sales_count: sale.fetch(:count, 0), gross_cents: sale.fetch(:gross, 0),
                    taxable_cents: sale.fetch(:taxable, 0), zero_rated_cents: sale.fetch(:zero_rated, 0),
                    non_taxable_cents: sale.fetch(:non_taxable, 0),
                    exempt_cents: sale.fetch(:exempt, 0), refund_count: refund[:count], refunded_cents: refund[:amount],
                    refunded_revenue_cents: refund[:revenue], refunded_tax_cents: refund[:tax],
                    tax_rows: tax_rows_for(code), payments: payments.fetch(code, []), periods: periods_for(code),
                    regions: regions.fetch(code, []), registrations: registrations.fetch(code, []))
      end

      # --- query building ---------------------------------------------------------------------------------------

      def order_table = Order.arel_table

      def line_item_table = LineItem.arel_table

      def tax_line_table = TaxLine.arel_table

      def category_table = TaxCategory.arel_table

      def payment_table = Payment.arel_table

      def refund_table = Refund.arel_table

      def registration_table = TaxRegistration.arel_table

      # The day an order counts on: its payment day, or the day it was invoiced.
      def date_column = basis == 'invoice' ? order_table[:placed_at] : order_table[:paid_at]

      def func(name, *args) = Arel::Nodes::NamedFunction.new(name, args)

      # The orders table narrowed to this platform, to paid orders, to the span and to the owner.
      def sale_condition
        @sale_condition ||= [order_table[:platform_id].eq(platform.id), order_table[:status].in(SALE_STATUSES),
                             date_column.between(from..to), owner.condition(order_table)].compact.reduce(:and)
      end

      # Orders keep to their own platform's rows: a child row must carry its parent's platform.
      def same_platform(child, parent) = child[:platform_id].eq(parent[:platform_id])

      # A line is "taxed" when it has a tax line; its base is its price without the tax inside it.
      def line_base = (line_item_table[:quantity] * line_item_table[:unit_amount_cents]) - line_item_table[:included_tax_cents]

      def taxed = TaxLine.where(tax_line_table[:line_item_id].eq(line_item_table[:id])).select(tax_line_table[:id]).arel.exists

      def sum_when(condition) = func('SUM', Arel::Nodes::Case.new.when(condition).then(line_base).else(0))

      # Revenue by kind, in the order of KINDS. An untaxed line is zero-rated, non-taxable or exempt, never two of them.
      def kind_sums
        untaxed = taxed.not
        ident = func('COALESCE', category_table[:identifier], Arel::Nodes.build_quoted(''))
        zero_rated = ident.in(ZERO_RATED_CATEGORIES)
        taxable_category = func('COALESCE', category_table[:taxable], Arel::Nodes.build_quoted(true)).eq(true)
        [sum_when(taxed), sum_when(untaxed.and(zero_rated)), sum_when(untaxed.and(zero_rated.not).and(category_table[:taxable].eq(false))),
         sum_when(untaxed.and(zero_rated.not).and(taxable_category))]
      end

      def sale_line_items
        LineItem.joins(:order).left_joins(:tax_category).where(same_platform(line_item_table, order_table)).where(sale_condition)
      end

      # [*keys, taxable, non_taxable, exempt] per group.
      def kind_rows(*keys) = sale_line_items.group(*keys).pluck(*keys, *kind_sums)

      # [*keys, sales_count, gross, tax] per group.
      def order_rows(*keys)
        Order.where(sale_condition).group(*keys).pluck(*keys, Arel.star.count, order_table[:total_cents].sum, order_table[:tax_cents].sum)
      end

      # --- sales and revenue ----------------------------------------------------------------------------------

      def sales
        @sales ||= begin
          result = order_rows(order_table[:currency]).to_h { |code, count, gross, _tax| [code, { count: count.to_i, gross: gross.to_i }] }
          kind_rows(order_table[:currency]).each { |code, *sums| result[code]&.merge!(kind_amounts(sums)) }
          result
        end
      end

      def kind_amounts(sums) = KINDS.zip(sums.map(&:to_i)).to_h.symbolize_keys

      # --- where the sales were taxed ---------------------------------------------------------------------------

      def regions
        @regions ||= order_rows(order_table[:currency], order_table[:tax_region_code]).group_by(&:first).transform_values do |rows|
          built = rows.map do |_code, region, count, gross, tax|
            RegionRow.new(region_code: region.to_s, sales_count: count.to_i, gross_cents: gross.to_i, tax_cents: tax.to_i)
          end
          built.sort_by { |row| [row.region_code.empty? ? 1 : 0, row.region_code] }
        end
      end

      def registrations
        @registrations ||= begin
          pairs = Order.where(sale_condition).group(order_table[:currency], order_table[:tax_registration_id])
                       .pluck(order_table[:currency], order_table[:tax_registration_id])
          found = TaxRegistration.where(platform_id: platform.id, id: pairs.filter_map(&:last)).index_by(&:id)
          known = pairs.select { |_code, id| found[id] }
          known.group_by(&:first).transform_values { |list| list.map { |_code, id| registration_row(found[id]) } }
        end
      end

      def registration_row(registration)
        RegistrationRow.new(country_iso: registration.country_iso, region_code: registration.region_code.to_s, status: registration.status,
                            collected_by: registration.seller_id ? 'seller' : 'platform', masked_number: mask(registration.registration_number))
      end

      def mask(number)
        text = number.to_s
        text.blank? ? nil : "#{'*' * [text.size - 4, 0].max}#{text.last(4)}"
      end

      # --- tax ------------------------------------------------------------------------------------------------

      def translation_table(name) = Arel::Table.new(:mobility_string_translations).alias(name)

      def label_current = @label_current ||= translation_table('cur')

      def label_english = @label_english ||= translation_table('en')

      def label_join(table, locale)
        tax_line_table.join(table, Arel::Nodes::OuterJoin).on(
          table[:translatable_type].eq(TaxLine.name).and(table[:translatable_id].eq(tax_line_table[:id]))
                                   .and(table[:key].eq('label')).and(table[:locale].eq(locale))
        )
      end

      # The tax line's label in the reader's language, else English, else blank.
      def label_expression
        @label_expression ||= func('COALESCE', label_current[:value], label_english[:value], Arel::Nodes.build_quoted(''))
      end

      # Who collected a tax line: the seller on its own registration, the platform on its own sale, or the platform for
      # a seller's sale (a facilitator: that tax is the platform's to remit, not the seller's).
      def collected_by_expression
        @collected_by_expression ||= Arel::Nodes::Case.new.when(registration_table[:seller_id].not_eq(nil)).then(Arel::Nodes.build_quoted('seller'))
                                                      .when(order_table[:seller_id].eq(nil)).then(Arel::Nodes.build_quoted('platform'))
                                                      .else(Arel::Nodes.build_quoted('facilitator'))
      end

      def registration_join
        order_table.join(registration_table, Arel::Nodes::OuterJoin).on(order_table[:tax_registration_id].eq(registration_table[:id])).join_sources
      end

      def tax_lines_with_labels
        TaxLine.joins(*[label_join(label_current, I18n.locale.to_s), label_join(label_english, 'en')].flat_map(&:join_sources))
      end

      # Tax lines with their order and the registration it was taxed under.
      def tax_lines_with_orders
        tax_lines_with_labels.joins(:order).joins(*registration_join).where(same_platform(tax_line_table, order_table))
      end

      def tax_key = [tax_line_table[:rate], tax_line_table[:included], label_expression, tax_line_table[:authority], collected_by_expression]

      def tax_collected
        @tax_collected ||= begin
          keys = [order_table[:currency], *tax_key]
          tax_lines_with_orders.where(sale_condition).group(*keys).order(label_expression.asc, tax_line_table[:rate].asc)
                               .pluck(*keys, tax_line_table[:amount_cents].sum).group_by(&:first)
        end
      end

      # [label, rate, included, authority, collected_by] from a pluck row: rate, included, label, authority, by.
      def tax_identity(rate, included, label, authority, collected_by) # rubocop:disable Metrics/ParameterLists
        [label, BigDecimal(rate.to_s), included, authority, collected_by]
      end

      def tax_rows_for(code)
        rows = tax_collected.fetch(code, []).to_h do |_code, *key, amount|
          [tax_identity(*key), { collected: amount.to_i, refunded: 0 }]
        end
        refund_tax_by_key.fetch(code, {}).each do |key, cents|
          (rows[key] ||= { collected: 0, refunded: 0 })[:refunded] += cents
        end
        ordered = rows.sort_by { |(label, rate, _, authority, by), _| [label.to_s, rate, authority.to_s, by.to_s] }
        ordered.map do |(label, rate, included, authority, by), cents|
          TaxRow.new(label:, rate:, included:, authority:, collected_by: by, collected_cents: cents[:collected],
                     refunded_cents: cents[:refunded])
        end
      end

      # --- refunds --------------------------------------------------------------------------------------------

      def refund_condition
        [order_table[:platform_id].eq(platform.id), refund_table[:status].in(REFUND_STATUSES),
         refund_table[:created_at].between(from..to), owner.condition(order_table)].compact.reduce(:and)
      end

      def refund_rows
        @refund_rows ||= Refund.joins(payment: :order)
                               .where(same_platform(refund_table, payment_table)).where(same_platform(payment_table, order_table))
                               .where(refund_condition).order(refund_table[:created_at].asc, refund_table[:id].asc)
                               .pluck(refund_table[:id], refund_table[:amount_cents], refund_table[:tax_cents],
                                      refund_table[:created_at], order_table[:id], order_table[:currency])
                               .map { |row| RefundRow.new(*row) }
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
          order_ids = refund_rows.map(&:order_id).uniq
          taxes = order_taxes(order_ids)
          kinds = order_kinds(order_ids)
          refund_rows.map { |row| allocation_for(row, taxes[row.order_id] || {}, kinds[row.order_id] || {}) }
        end
      end

      def allocation_for(row, order_tax, order_kind)
        tax = row.tax_cents.to_i
        net = row.amount_cents.to_i - tax
        { currency: row.currency, amount: row.amount_cents.to_i, tax:, created_at: row.created_at,
          tax_by_key: allocate(tax, order_tax), revenue: allocate(net, order_kind.presence || { 'exempt' => 1 }),
          net: }
      end

      def order_taxes(order_ids)
        return {} if order_ids.empty?

        keys = [tax_line_table[:order_id], *tax_key]
        rows = tax_lines_with_orders.where(tax_line_table[:platform_id].eq(platform.id).and(tax_line_table[:order_id].in(order_ids)))
                                    .group(*keys).pluck(*keys, tax_line_table[:amount_cents].sum)
        rows.group_by(&:first).transform_values do |list|
          list.to_h { |_id, *key, amount| [tax_identity(*key), amount.to_i] }
        end
      end

      def order_kinds(order_ids)
        return {} if order_ids.empty?

        rows = LineItem.left_joins(:tax_category)
                       .where(line_item_table[:platform_id].eq(platform.id).and(line_item_table[:order_id].in(order_ids)))
                       .group(line_item_table[:order_id]).pluck(line_item_table[:order_id], *kind_sums)
        rows.to_h { |order_id, *sums| [order_id, KINDS.zip(sums.map(&:to_i)).to_h] }
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
        @payments ||= payment_rows.group_by(&:first).transform_values do |rows|
          rows.map do |_code, processor, count, amount|
            PaymentRow.new(processor:, payment_count: count.to_i, amount_cents: amount.to_i)
          end
        end
      end

      def payment_rows
        Payment.joins(:order).where(same_platform(payment_table, order_table))
               .where(sale_condition.and(payment_table[:status].in(PAYMENT_STATUSES)))
               .group(order_table[:currency], payment_table[:processor]).order(payment_table[:processor].asc)
               .pluck(order_table[:currency], payment_table[:processor], Arel.star.count, payment_table[:amount_cents].sum)
      end

      # --- one row per month, quarter or year ---------------------------------------------------------------------

      # Timestamps are stored in UTC without a zone: say so, then move them to the platform's zone and cut to the interval.
      def bucket(column)
        utc = Arel::Nodes::InfixOperation.new('AT TIME ZONE', column, Arel::Nodes.build_quoted('UTC'))
        local = Arel::Nodes::InfixOperation.new('AT TIME ZONE', Arel::Nodes::Grouping.new(utc), Arel::Nodes.build_quoted(platform.time_zone))
        func('CAST', func('date_trunc', Arel::Nodes.build_quoted(interval), Arel::Nodes::Grouping.new(local)).as('date'))
      end

      def periods_for(code)
        buckets = period_sales.fetch(code, {}).merge(period_refunds.fetch(code, {})) { |_k, a, b| a.merge(b) }
        buckets.keys.sort.map do |day|
          row = { sales_count: 0, gross: 0, taxable: 0, zero_rated: 0, non_taxable: 0, exempt: 0, tax: 0, refunded: 0,
                  refunded_tax: 0 }.merge(buckets[day])
          PeriodRow.new(starts_on: day, sales_count: row[:sales_count], gross_cents: row[:gross], taxable_cents: row[:taxable],
                        zero_rated_cents: row[:zero_rated], non_taxable_cents: row[:non_taxable], exempt_cents: row[:exempt],
                        tax_cents: row[:tax],
                        refunded_cents: row[:refunded], refunded_tax_cents: row[:refunded_tax])
        end
      end

      def period_sales
        @period_sales ||= begin
          keys = [order_table[:currency], bucket(date_column)]
          result = Hash.new { |h, k| h[k] = {} }
          order_rows(*keys).each do |code, day, count, gross, tax|
            result[code][day.to_date] = { sales_count: count.to_i, gross: gross.to_i, tax: tax.to_i }
          end
          kind_rows(*keys).each { |code, day, *sums| result[code][day.to_date]&.merge!(kind_amounts(sums)) }
          result
        end
      end

      # Refunds fall in the period they were recorded in, cut by the same zone and interval.
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
        local = time.in_time_zone(platform.time_zone)
        case interval
        when 'year' then local.beginning_of_year.to_date
        when 'quarter' then local.beginning_of_quarter.to_date
        else local.beginning_of_month.to_date
        end
      end
    end
    # rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength
  end
end
