# frozen_string_literal: true

module BetterTogether
  # The order summary as aligned plain text, for the text part of an email. It reads the same Orders::Summary the
  # pages and the HTML email read, so the figures and the order of the rows are the same.
  module BillingSummaryHelper
    GAP = '   '

    def billing_summary_text(summary)
      money = ->(cents) { billing_amount(cents, summary.currency) }
      items = summary_items(summary, money)
      rows = summary_rows(summary, money)
      [*aligned(items, rows), *summary_registrations(summary)].join("\n")
    end

    private

    # Every amount, the items' and the rows', ends in one column: the items' text on the left, the rows' labels
    # against the right, so the figures line up the way they do on the page.
    def aligned(items, rows)
      amount_width = column_width(items + rows, :last)
      text_width = [column_width(items, :first), column_width(rows, :first)].max
      [*items.map { |text, amount| "#{text.ljust(text_width)}#{GAP}#{amount.rjust(amount_width)}" }, '',
       *rows.map { |label, amount| "#{label.rjust(text_width)}#{GAP}#{amount.rjust(amount_width)}" }]
    end

    def column_width(pairs, which) = pairs.map { |pair| pair.public_send(which).length }.max.to_i

    # [text, amount]: the item, the tax marker when the order has tax, the quantity; then its amount.
    def summary_items(summary, money)
      summary.lines.map do |line|
        marker = t(line.taxed ? 'better_together.billing.order_summary.taxed' : 'better_together.billing.order_summary.not_taxed')
        text = [line.description, (marker if summary.taxed?), "x#{line.quantity}"].compact.join(GAP)
        [text, money.call(line.amount_cents)]
      end
    end

    def summary_rows(summary, money)
      rows = []
      if summary.taxed?
        rows << [t('better_together.billing.orders.field_subtotal'), money.call(summary.subtotal_cents)]
        summary.tax_rows.each { |row| rows << [tax_row_label(row, money), money.call(row.amount_cents)] }
      end
      rows << [t('better_together.billing.orders.field_total'), money.call(summary.total_cents)]
    end

    def tax_row_label(row, money)
      label = t('better_together.billing.order_summary.tax_on', label: row.label, rate: row.percent, base: money.call(row.base_cents))
      row.included ? "#{label} #{t('better_together.billing.order_summary.included')}" : label
    end

    def summary_registrations(summary)
      return [] if summary.registrations.empty?

      ['', t('better_together.billing.order_summary.registrations'),
       *summary.registrations.map do |r|
         t('better_together.billing.order_summary.registration', labels: r.labels.join(' / '), number: r.number)
       end]
    end
  end
end
