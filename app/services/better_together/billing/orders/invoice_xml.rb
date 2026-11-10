# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # The order as a Factur-X / ZUGFeRD invoice: UN/CEFACT Cross Industry Invoice XML in the BASIC WL profile
      # (`urn:factur-x.eu:1p0:basicwl`), the machine-readable half of the PDF for EU e-invoicing. It carries the
      # seller and buyer, one tax breakdown per tax (so GST and QST, or two VATs, stay separate), the registration
      # numbers, and the totals, including what is already paid and what is still due.
      #
      # It is built from the same Orders::Summary as the pages and the PDF. Lines are not in this profile; they are in
      # the JSON-LD copy (see Orders::InvoiceJson). Nothing here has been validated against the Factur-X schema or a
      # national platform; a Canadian order carries its taxes as ordinary tax breakdowns and is not an EU invoice.
      class InvoiceXml
        PROFILE = 'urn:factur-x.eu:1p0:basicwl'
        NAMESPACES = {
          'xmlns:rsm' => 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100',
          'xmlns:ram' => 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100',
          'xmlns:udt' => 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100'
        }.freeze
        INVOICE_TYPE_CODE = '380'

        def initialize(order, summary:, seller_name:, time_zone:)
          @order = order
          @summary = summary
          @seller_name = seller_name
          @time_zone = time_zone
        end

        def to_xml
          builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
            xml['rsm'].CrossIndustryInvoice(NAMESPACES) do
              context(xml)
              document(xml)
              transaction(xml)
            end
          end
          builder.to_xml
        end

        private

        attr_reader :order, :summary

        def context(xml)
          xml['rsm'].ExchangedDocumentContext do
            xml['ram'].GuidelineSpecifiedDocumentContextParameter { xml['ram'].ID PROFILE }
          end
        end

        def document(xml)
          xml['rsm'].ExchangedDocument do
            xml['ram'].ID order.number
            xml['ram'].TypeCode INVOICE_TYPE_CODE
            xml['ram'].IssueDateTime { date(xml, order.placed_at || order.created_at) }
          end
        end

        def transaction(xml)
          xml['rsm'].SupplyChainTradeTransaction do
            xml['ram'].ApplicableHeaderTradeAgreement do
              seller(xml)
              xml['ram'].BuyerTradeParty { xml['ram'].Name order.buyer.name }
            end
            xml['ram'].ApplicableHeaderTradeDelivery
            settlement(xml)
          end
        end

        def seller(xml) # rubocop:disable Metrics/AbcSize
          xml['ram'].SellerTradeParty do
            xml['ram'].Name @seller_name
            country = seller_country
            xml['ram'].PostalTradeAddress { xml['ram'].CountryID country } if country
            summary.registrations.each do |registration|
              xml['ram'].SpecifiedTaxRegistration { xml['ram'].ID registration.number, schemeID: 'FC' }
            end
          end
        end

        # Where the tax is collected from, when the order was taxed.
        def seller_country = order.tax_registration&.country_iso.presence || Configuration.default_country

        def settlement(xml)
          xml['ram'].ApplicableHeaderTradeSettlement do
            xml['ram'].InvoiceCurrencyCode summary.currency
            summary.tax_rows.each { |row| tax_breakdown(xml, row) }
            xml['ram'].SpecifiedTradeSettlementHeaderMonetarySummation do
              totals(xml)
            end
          end
        end

        def tax_breakdown(xml, row)
          xml['ram'].ApplicableTradeTax do
            xml['ram'].CalculatedAmount amount(row.amount_cents)
            xml['ram'].TypeCode 'VAT'
            xml['ram'].BasisAmount amount(row.base_cents)
            xml['ram'].CategoryCode 'S'
            xml['ram'].RateApplicablePercent percent(row)
          end
        end

        def totals(xml) # rubocop:disable Metrics/AbcSize
          net = summary.subtotal_cents - (summary.tax_cents - summary.added_tax_cents)
          xml['ram'].LineTotalAmount amount(net)
          xml['ram'].TaxBasisTotalAmount amount(net)
          xml['ram'].TaxTotalAmount amount(summary.tax_cents), currencyID: summary.currency
          xml['ram'].GrandTotalAmount amount(summary.total_cents)
          xml['ram'].TotalPrepaidAmount amount(order.net_paid_cents)
          xml['ram'].DuePayableAmount amount(order.balance_cents)
        end

        def date(xml, time)
          xml['udt'].DateTimeString time.in_time_zone(@time_zone).strftime('%Y%m%d'), format: '102'
        end

        def amount(cents)
          format('%.*f', Currency.exponent(summary.currency), Currency.to_major(cents, summary.currency))
        end

        def percent(row) = row.percent.delete('%')
      end
    end
  end
end
