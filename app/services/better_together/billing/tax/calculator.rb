# frozen_string_literal: true

module BetterTogether
  module Billing
    module Tax
      # Works out the tax on what is being sold. It reads plain values and returns plain values, writes nothing,
      # and can be run again with the same answer.
      #
      #   Tax::Calculator.call(platform:, seller:, items: [Tax::Calculator::Item.new(amount_cents: 4500, tax_category: nil)],
      #                        country_iso: 'CA', region_code: 'NL')
      #
      # The buyer's place can instead be a `settlement:` (a Geography::Settlement), which brings its state and country,
      # so a municipal tax is found as well as the state's and the country's.
      #
      # Whose tax: the seller's own registration if the seller has one, otherwise the platform's. If that
      # registration does not collect (small supplier, exempt, switched off), or there is none, there is no tax.
      # Where: the buyer's place if given, else the registrant's own place. A registration only applies to the
      # place it is for: with several (one per country or region), the one for the buyer's country is used, a
      # region's own before a country-wide one, and a buyer somewhere none covers is not taxed.
      # How much: each rate that is in force for the place and fits the item's category, on the item's amount.
      # An item in a category that is not taxable is not taxed. Store credit and other payments never change the
      # amount tax is worked out on.
      #
      # Prices that include tax have it taken out of the price (the total does not change); otherwise it is
      # added. Each amount is rounded half up to the minor unit.
      # Each tax carries the registration number of the registration covering its zone (the settlement's, else the
      # state's, else the country's), from the same registrant, so a QST and a GST each show their own number.
      class Calculator
        Item = Data.define(:amount_cents, :tax_category)
        Line = Data.define(:item_index, :tax_rate, :label, :rate, :amount_cents, :included, :registration_number, :authority)
        Result = Data.define(:registration, :country_iso, :region_code, :settlement, :prices_include_tax, :lines) do
          def taxed? = lines.any?
          def tax_cents = lines.sum(&:amount_cents)
          def included_cents = lines.select(&:included).sum(&:amount_cents)
          # What is added to the price.
          def additional_cents = tax_cents - included_cents
          def lines_for(index) = lines.select { |line| line.item_index == index }
        end

        def self.call(...) = new(...).call

        # The tax on a purchase described the way Orders::Place is given it: hashes with a `purchasable:`, an optional
        # `quantity:` and an optional `unit_amount_cents:` (the price it was sold at, when it differs from the purchasable's own).
        def self.for_lines(line_items, **)
          items = line_items.map do |line|
            purchasable = line.fetch(:purchasable)
            unit = line.fetch(:unit_amount_cents) { purchasable.purchasable_amount_cents }
            Item.new(amount_cents: unit * line.fetch(:quantity, 1), tax_category: purchasable.purchasable_tax_category)
          end
          call(items:, **)
        end

        def initialize(platform:, items:, seller: nil, country_iso: nil, region_code: nil, settlement: nil) # rubocop:disable Metrics/ParameterLists
          @platform = platform
          @seller = seller
          @items = items
          @country_iso = country_iso.to_s.upcase.presence
          @region_code = region_code.to_s.upcase.presence
          @settlement = settlement
          @at = Time.current
        end

        def call
          return none unless registration&.collects?

          Result.new(registration:, country_iso: place.country_iso, region_code: place.region_code, settlement: place.settlement,
                     prices_include_tax: registration.prices_include_tax?, lines: tax_lines)
        end

        private

        attr_reader :platform, :seller, :items, :at

        def none
          Result.new(registration:, country_iso: place.country_iso, region_code: place.region_code, settlement: place.settlement,
                     prices_include_tax: nil, lines: [])
        end

        def registration
          return @registration if defined?(@registration)

          scope = platform.billing_tax_registrations.in_force_at(at)
          @registration = (seller && registration_for(scope.sold_by(seller))) || registration_for(scope.sold_by_platform)
        end

        # The registration that covers the buyer's place: its country, and its region when it names one. Without a
        # buyer's place any registration will do, and the place is then its own.
        def registration_for(scope)
          candidates = scope.order(:created_at).to_a
          return candidates.last unless buyer_place?

          covering = candidates.select { |candidate| covers_buyer?(candidate) }
          covering.reverse.find { |candidate| candidate.region_code.present? } || covering.last
        end

        def covers_buyer?(candidate)
          candidate.country_iso == buyer_country_iso && (candidate.region_code.blank? || candidate.region_code == buyer_region_code)
        end

        def buyer_place? = @settlement.present? || @country_iso.present?

        def buyer_country_iso = @buyer_country_iso ||= buyer_place.country_iso || @country_iso

        def buyer_region_code = @buyer_region_code ||= buyer_place.region_code || @region_code

        def buyer_place = @buyer_place ||= Place.resolve(country_iso: @country_iso, region_code: @region_code, settlement: @settlement)

        # The buyer's place if one was given, else the registrant's own.
        def place
          @place ||= if buyer_place?
                       buyer_place
                     else
                       Place.resolve(country_iso: registration&.country_iso, region_code: registration&.region_code)
                     end
        end

        def rates = @rates ||= TaxRate.active_at(at).where(platform_id: platform.id, tax_zone_id: zones.select(:id)).order(:created_at).to_a

        def zones = TaxZone.where(platform_id: platform.id).covering(place)

        def tax_lines
          items.each_with_index.flat_map { |item, index| item_lines(item, index) }
        end

        def item_lines(item, index)
          return [] unless taxable?(item)

          fitting = rates.select { |rate| rate.applies_to?(item.tax_category) }
          divisor = included? ? 1 + fitting.sum(&:rate) : 1
          fitting.map { |rate| line_for(item, index, rate, divisor) }
        end

        def line_for(item, index, rate, divisor)
          Line.new(item_index: index, tax_rate: rate, label: rate.label, rate: rate.rate, included: included?,
                   amount_cents: tax_amount(item.amount_cents, rate.rate, divisor), registration_number: number_for(rate),
                   authority: rate.authority)
        end

        # The registrant's collecting registrations, narrowest place first; the registrant is the one chosen above.
        def registrations_of_registrant
          @registrations_of_registrant ||= begin
            scope = platform.billing_tax_registrations.in_force_at(at)
            scope = registration.seller_id ? scope.sold_by(seller) : scope.sold_by_platform
            scope.order(:created_at).to_a.select(&:collects?)
          end
        end

        def number_for(rate)
          covering = covering_registrations(rate.tax_zone)
          [zone_region(rate.tax_zone), nil].uniq.each do |code|
            found = covering.reverse.find { |c| c.region_code.presence == code }
            return found.registration_number.presence if found
          end
          nil
        end

        def covering_registrations(zone) = registrations_of_registrant.select { |c| c.country_iso == zone.country.iso_code }

        def zone_region(zone) = zone.state && zone.state.iso_code.split('-', 2).last

        def included? = registration.prices_include_tax?

        def tax_amount(amount_cents, rate, divisor) = (BigDecimal(amount_cents) * rate / divisor).round(0, BigDecimal::ROUND_HALF_UP).to_i

        def taxable?(item) = item.amount_cents.positive? && item.tax_category&.taxable != false
      end
    end
  end
end
