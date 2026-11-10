# frozen_string_literal: true

module BetterTogether
  # The order summary as aligned plain text, for the text part of an email. It reads the same Orders::Summary the
  # pages and the HTML email read, so the figures and the order of the rows are the same.
  module BillingSummaryHelper
    GAP = '   '

    def billing_summary_text(summary)
      money = ->(cents) { billing_amount(cents, summary.currency) }
      item_lines = summary_item_lines(summary, money)
      rows = summary_rows(summary, money)
      [*item_lines, '', *right_aligned(rows, summary_width(item_lines, rows)), *summary_registrations(summary)].join("\n")
    end

    private

    def summary_width(item_lines, rows)
      [item_lines.map(&:length).max.to_i, rows.map { |label, amount| label.length + GAP.length + amount.length }.max.to_i].max
    end

    def summary_item_lines(summary, money)
      summary.lines.map do |line|
        text = "#{line.description} x#{line.quantity}#{GAP}#{money.call(line.amount_cents)}"
        next text unless summary.taxed?

        "#{text}#{GAP}#{t(line.taxed ? 'better_together.billing.order_summary.taxed' : 'better_together.billing.order_summary.not_taxed')}"
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

    def right_aligned(rows, width)
      amount_width = rows.map { |_label, amount| amount.length }.max.to_i
      rows.map { |label, amount| "#{label.rjust(width - amount_width - GAP.length)}#{GAP}#{amount.rjust(amount_width)}" }
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
