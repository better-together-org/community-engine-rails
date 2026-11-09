# frozen_string_literal: true

module BetterTogether
  module Billing
    module Tax
      module Seeds
        # Canadian sales tax as data: one zone per province or territory, with the rates that apply there today.
        # Safe to run again: it only adds what is missing and never changes a rate that exists (a rate that moves
        # is a new row with its own dates, so orders already placed keep the rate they were charged).
        #
        # Every figure below comes from an official government page, read in November 2026. The date after each
        # link is the one the page itself shows ("Date modified", "Last updated" or "Revised"), or says so when
        # the page shows none. Check the pages again before relying on a figure after those dates.
        #
        # GST/HST rates, by province and territory (CRA, "GST/HST calculator (and rates)", table "On or after
        # April 1, 2025", which also gives the PST/QST column used below). Date modified: 2025-04-01.
        #   https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/gst-hst-businesses/charge-collect-which-rate/calculator.html
        #   GST 5% is the rate where the province does not take part in the HST; HST is 13% in Ontario, 14% in Nova
        #   Scotia (down from 15% on April 1, 2025) and 15% in New Brunswick, Newfoundland and Labrador and
        #   Prince Edward Island. The same table lists the QST at 9.975%, the British Columbia and Manitoba PST/RST
        #   at 7% and the Saskatchewan PST at 6%.
        #
        # Basic groceries are zero-rated for GST/HST in every province and territory (CRA, "Which rate to
        # charge"). Page details date: 2026-04-08 (the page shows the date without a label).
        #   https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/gst-hst-businesses/charge-collect-which-rate.html
        #
        # British Columbia PST, 7% "generally" (Province of B.C., "Provincial Sales Tax (PST)"). Last updated on
        # September 21, 2026. Food for human consumption, such as basic groceries, is exempt (same site,
        # "PST exemptions", last updated on August 20, 2025).
        #   https://www2.gov.bc.ca/gov/content/taxes/sales-taxes/pst
        #   https://www2.gov.bc.ca/gov/content/taxes/sales-taxes/pst/exemptions
        #
        # Saskatchewan PST, 6% (Government of Saskatchewan, "Provincial Sales Tax"). The page shows no date.
        #   https://www.saskatchewan.ca/business/taxes-licensing-and-reporting/provincial-taxes-policies-and-bulletins/provincial-sales-tax
        #
        # Manitoba RST, 7%, worked out on the selling price before GST (Manitoba Finance, "Retail Sales Tax").
        # The page shows no date. Basic groceries and most other food are exempt (Information Bulletin RST 030,
        # Revised: July 2026).
        #   https://www.gov.mb.ca/finance/taxation/taxes/retail.html
        #   https://www.gov.mb.ca/finance/taxation/pubs/bulletins/030.pdf
        #
        # NOT yet confirmed on an official page the tool could read: Revenu Quebec refused automated reads
        # (HTTP 403), so the QST rate rests on the CRA table above, and the Quebec grocery rule and the
        # Saskatchewan grocery rule (Information Bulletin PST-2, publications.saskatchewan.ca, TLS error) were not
        # read. Until someone confirms them, the basic groceries category is treated as untaxed everywhere: the
        # CRA, B.C. and Manitoba pages above say so for GST/HST, B.C. PST and Manitoba RST.
        class Canada
          Province = Struct.new(:region, :name, :rates)

          GROCERIES = 'basic_groceries'
          STANDARD = 'standard'

          PROVINCES = [
            Province.new('AB', 'Alberta', [['GST', '0.05']]),
            Province.new('BC', 'British Columbia', [['GST', '0.05'], ['PST', '0.07']]),
            Province.new('MB', 'Manitoba', [['GST', '0.05'], ['RST', '0.07']]),
            Province.new('NB', 'New Brunswick', [['HST', '0.15']]),
            Province.new('NL', 'Newfoundland and Labrador', [['HST', '0.15']]),
            Province.new('NS', 'Nova Scotia', [['HST', '0.14']]),
            Province.new('NT', 'Northwest Territories', [['GST', '0.05']]),
            Province.new('NU', 'Nunavut', [['GST', '0.05']]),
            Province.new('ON', 'Ontario', [['HST', '0.13']]),
            Province.new('PE', 'Prince Edward Island', [['HST', '0.15']]),
            Province.new('QC', 'Quebec', [['GST', '0.05'], ['QST', '0.09975']]),
            Province.new('SK', 'Saskatchewan', [['GST', '0.05'], ['PST', '0.06']]),
            Province.new('YT', 'Yukon', [['GST', '0.05']])
          ].freeze

          # When a seller must start collecting, in whole dollars of taxable sales (dollars, not cents: these
          # are the figures the governments print). Used by the small supplier monitor (T5).
          #
          # GST/HST: $30,000 ($50,000 for a public service body) in a single calendar quarter or over the last
          # four consecutive calendar quarters, worldwide, with associates; financial services, capital property
          # and goodwill are left out. Taxis and commercial ridesharing must register at once. The sale that
          # takes a seller over the limit is taxed. CRA, "General Information for GST/HST Registrants" (RC4022(E)
          # Rev. 25; the page date was not retrieved).
          #   https://www.canada.ca/en/revenue-agency/services/forms-publications/publications/rc4022/general-information-gst-hst-registrants.html
          #
          # B.C. PST small seller: $10,000 or less in the last 12 months and expected in the next 12, and no
          # established business premises, and not an online marketplace facilitator. Bulletin PST 003,
          # Revised: July 2026.
          #   https://www2.gov.bc.ca/assets/gov/taxes/sales-taxes/publications/pst-003-small-sellers.pdf
          #
          # Saskatchewan small trader: under $10,000 of sales, made from home; the guideline does not reach
          # sales at a farmers' market or on an online marketplace. Information Bulletin PST-5, Revised: July 2025.
          #   https://sets.saskatchewan.ca/rptp/wcm/connect/2f7bed69-f481-4fca-8b2d-f80c2acf7d99/PST.005+Registration+and+Reporting+Requirements.pdf?MOD=AJPERES
          #
          # Manitoba: annual taxable sales under $30,000 need not register; one month to register after going
          # over. Information Notice RST 24-01, Issued: April 2024; Bulletin RST 004, Revised: June 2024.
          #   https://gov.mb.ca/finance/taxation/pubs/bulletins/noticerst2401.pdf
          #   https://gov.mb.ca/finance/taxation/pubs/bulletins/004.pdf
          #
          # Quebec QST: $30,000 over the same quarters as the GST, per a Revenu Quebec page this tool could not
          # read directly (HTTP 403); confirm before use.
          #   https://www.revenuquebec.ca/en/businesses/consumption-taxes/gsthst-and-qst/registering-for-the-gst-and-qst/
          SMALL_SUPPLIER_DOLLARS = {
            'GST/HST' => { general: 30_000, public_service_body: 50_000, quarters: 4 },
            'BC PST' => { general: 10_000, months: 12 },
            'SK PST' => { general: 10_000 },
            'MB RST' => { general: 30_000, months: 12 },
            'QC QST' => { general: 30_000, quarters: 4 }
          }.freeze

          # Marketplaces: a seller who sells only through a marketplace whose operator collects the buyer's
          # payment and the tax need not collect it. B.C., Saskatchewan and Manitoba each say so (Bulletin
          # PST 142, Revised: March 2025; Bulletin PST-5, Revised: July 2025; The Retail Sales Tax Act,
          # C.C.S.M. c. R130, s. 21.2(2), shown as current from 1 July 2026 to 28 October 2026). It is why a seller may stop collecting
          # only when payments do not go through the platform's own payment processors.
          #   https://www2.gov.bc.ca/assets/gov/taxes/sales-taxes/publications/pst-142-marketplace-facilitators.pdf
          #   https://web2.gov.mb.ca/laws/statutes/ccsm/_pdf.php?cap=r130

          def self.call(platform:) = new(platform).call

          def initialize(platform)
            @platform = platform
          end

          def call
            ::ActiveRecord::Base.transaction do
              seed_categories
              PROVINCES.each { |province| seed_province(province) }
            end
          end

          private

          attr_reader :platform

          def seed_categories
            find_category(STANDARD, 'Standard', taxable: true)
            find_category(GROCERIES, 'Basic groceries', taxable: false)
          end

          def find_category(identifier, name, taxable:)
            Billing::TaxCategory.find_or_create_by!(platform:, identifier:) do |category|
              category.name = name
              category.taxable = taxable
            end
          end

          def seed_province(province)
            zone = Billing::TaxZone.find_or_create_by!(platform:, country_iso: 'CA', region_code: province.region) do |new_zone|
              new_zone.name = province.name
            end
            province.rates.each do |label, rate|
              Billing::TaxRate.find_or_create_by!(platform:, tax_zone: zone, label:, discarded_at: nil) do |tax_rate|
                tax_rate.rate = BigDecimal(rate)
              end
            end
          end
        end
      end
    end
  end
end
