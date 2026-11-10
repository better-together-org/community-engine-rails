# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # The order as schema.org JSON-LD (an Invoice that references its Order), embedded in the PDF next to the
      # Factur-X XML. It carries what the XML profile has no room for: each line, whether it is taxed, and each tax with
      # what it applies to. Built from the same Orders::Summary as the pages.
      class InvoiceJson
        def initialize(order, summary:, seller_name:, time_zone:, kind:)
          @order = order
          @summary = summary
          @seller_name = seller_name
          @time_zone = time_zone
          @kind = kind
        end

        def to_h # rubocop:disable Metrics/AbcSize
          {
            '@context' => 'https://schema.org',
            '@type' => 'Invoice',
            'identifier' => @order.number,
            'description' => @kind.to_s,
            'paymentStatus' => @order.status,
            'provider' => provider,
            'customer' => { '@type' => 'Person', 'name' => @order.buyer.name },
            'referencesOrder' => order_node,
            'totalPaymentDue' => money(@order.balance_cents),
            'dateCreated' => (@order.placed_at || @order.created_at).in_time_zone(@time_zone).iso8601
          }.compact
        end

        def to_json(*) = JSON.pretty_generate(to_h)

        private

        def provider
          registrations = @summary.registrations.map do |r|
            { '@type' => 'PropertyValue', 'name' => r.labels.join(' / '), 'value' => r.number }
          end
          { '@type' => 'Organization', 'name' => @seller_name, 'identifier' => registrations.presence }.compact
        end

        def order_node
          {
            '@type' => 'Order', 'orderNumber' => @order.number, 'priceCurrency' => @summary.currency,
            'price' => decimal(@summary.total_cents),
            'orderedItem' => @summary.lines.each_with_index.map { |line, index| item(line, index) },
            'additionalProperty' => tax_nodes
          }.compact
        end

        def item(line, index)
          { '@type' => 'OrderItem', 'orderItemNumber' => (index + 1).to_s, 'orderQuantity' => line.quantity,
            'orderedItem' => { '@type' => 'Product', 'name' => line.description },
            'price' => decimal(line.amount_cents), 'priceCurrency' => @summary.currency,
            'additionalProperty' => { '@type' => 'PropertyValue', 'name' => 'taxed', 'value' => line.taxed } }
        end

        def tax_nodes
          @summary.tax_rows.map do |row|
            { '@type' => 'PropertyValue', 'name' => row.label, 'value' => decimal(row.amount_cents),
              'unitText' => "#{row.percent} on #{decimal(row.base_cents)}#{' (included in the price)' if row.included}" }
          end.presence
        end

        def money(cents) = { '@type' => 'MonetaryAmount', 'currency' => @summary.currency, 'value' => decimal(cents) }

        def decimal(cents)
          format('%.*f', Currency.exponent(@summary.currency), Currency.to_major(cents, @summary.currency))
        end
      end
    end
  end
end
