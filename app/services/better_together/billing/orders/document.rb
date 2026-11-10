# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # The order as a PDF, in the shape the order pages and the emails show it: the same lines, the same row for each
      # tax, the same total and the same registration numbers, because it is built from the same Orders::Summary.
      #
      #   Orders::Document.new(order).to_pdf           # an invoice while it is unpaid, a receipt once it is paid
      #   Orders::Document.new(order, kind: :invoice)  # the invoice of an order that is paid
      #
      # A receipt of an order with refunds shows what was refunded and what is left paid. Like the email it goes in,
      # it carries no payment instructions, no payee details and no processor text, so a forwarded copy cannot be
      # used to redirect a payment. The file name carries only the order number.
      class Document # rubocop:disable Metrics/ClassLength
        PAID_STATUSES = %w[paid partially_refunded refunded].freeze
        KINDS = %i[invoice receipt].freeze

        attr_reader :order, :kind, :summary

        def initialize(order, kind: nil, locale: nil)
          @order = order
          @kind = (kind || (PAID_STATUSES.include?(order.status) ? :receipt : :invoice)).to_sym
          raise ArgumentError, "unknown document kind #{@kind.inspect}" unless KINDS.include?(@kind)

          @locale = locale || I18n.locale
          @summary = Summary.for_order(order)
        end

        def filename = "#{kind}-#{order.number}.pdf"

        # What goes on the page, by part, in the reader's language. The same figures as the pages and emails.
        def sections
          @sections ||= I18n.with_locale(@locale) do
            { company:, recipient: [order.buyer.name], details:, items: item_table, totals: total_rows, footer: footer }
          end
        end

        def to_pdf
          I18n.with_locale(@locale) { build.render }
        end

        private

        # Receipts draws one table of items; the totals under it are a second, narrower table at the right, so a
        # long tax label has room and the amounts line up.
        def build # rubocop:disable Metrics/AbcSize
          pdf = (kind == :receipt ? ::Receipts::Receipt : ::Receipts::Invoice).new
          pdf.title = doc_text("title_#{kind}")
          pdf.header(company: sections[:company])
          pdf.render_details(sections[:details])
          pdf.render_billing_details(company: sections[:company], recipient: sections[:recipient])
          pdf.render_line_items(line_items: sections[:items], column_widths: column_widths)
          render_totals(pdf)
          pdf.render_footer(sections[:footer])
          pdf
        end

        def render_totals(pdf)
          pdf.move_down(8)
          pdf.table(sections[:totals], width: pdf.bounds.width * 0.7, position: :right,
                                       cell_style: { borders: [], padding: [3, 6], align: :right, inline_format: true })
        end

        def company
          { name: business_name, address: Pay.business_address.presence, email: support_email }.compact
        end

        # Pay hands the support address back as a Mail::Address, which is never blank, even when none is set.
        def support_email = Pay.support_email.try(:address).presence

        def business_name = Pay.business_name.presence || order.platform&.name.to_s

        def details
          [[t_order(:field_number), order.number], [t_order(:field_status), t_order("status_#{order.status}")],
           [t_order(:field_placed), date(order.placed_at)], *paid_details].reject { |_label, value| value.blank? }
        end

        def paid_details
          return [] unless kind == :receipt

          [[t_order(:field_paid), date(order.paid_at)], [t_order(:field_method), methods_used]]
        end

        def methods_used
          order.payments.select { |payment| PAID_STATUSES.include?(payment.status) || payment.status == 'succeeded' }.map(&:processor).uniq
               .map { |name| I18n.t("better_together.billing.plans.payment_method_names.#{name}", default: name.to_s.humanize) }.join(', ')
        end

        # The heading, then a row for each item.
        def item_table
          [heading, *item_rows]
        end

        def heading
          cells = [t_order(:field_item)]
          cells << doc_text(:tax_heading) if summary.taxed?
          [*cells, t_order(:field_quantity), t_order(:field_amount)].map { |text| "<b>#{text}</b>" }
        end

        def item_rows
          summary.lines.map do |line|
            cells = [line.description]
            cells << t_summary(line.taxed ? :taxed : :not_taxed) if summary.taxed?
            [*cells, line.quantity.to_s, money(line.amount_cents)]
          end
        end

        def total_rows # rubocop:disable Metrics/AbcSize
          rows = []
          if summary.taxed?
            rows << [t_order(:field_subtotal), money(summary.subtotal_cents)]
            summary.tax_rows.each { |row| rows << [tax_label(row), money(row.amount_cents)] }
          end
          rows << [t_order(:field_total), money(summary.total_cents)]
          rows.concat(refund_rows)
          rows.map { |label, amount| [label, "<b>#{amount}</b>"] }
        end

        def refund_rows
          return [] unless kind == :receipt && order.refunded_cents.positive?

          [[doc_text(:refunded), "-#{money(order.refunded_cents)}"], [doc_text(:net_paid), money(order.net_paid_cents)]]
        end

        def tax_label(row)
          label = t_summary(:tax_on, label: row.label, rate: row.percent, base: money(row.base_cents))
          row.included ? "#{label} #{t_summary(:included)}" : label
        end

        def column_widths = summary.taxed? ? [nil, 70, 50, 80] : [nil, 50, 90]

        def footer # rubocop:disable Metrics/AbcSize
          lines = []
          if summary.registrations.any?
            lines << "<b>#{t_summary(:registrations)}</b>"
            lines.concat(summary.registrations.map { |r| t_summary(:registration, labels: r.labels.join(' / '), number: r.number) })
          end
          email = support_email
          lines << doc_text(:questions, email:) if email
          lines.join("\n")
        end

        def money(cents)
          currency = summary.currency
          ActionController::Base.helpers.number_to_currency(Currency.to_major(cents, currency), unit: Currency.unit(currency),
                                                                                                precision: Currency.exponent(currency))
        end

        def date(time) = time ? I18n.l(time.to_date, format: :long) : nil

        def doc_text(key, **) = I18n.t("better_together.billing.document.#{key}", **)

        def t_order(key) = I18n.t("better_together.billing.orders.#{key}")

        def t_summary(key, **) = I18n.t("better_together.billing.order_summary.#{key}", **)
      end
    end
  end
end
