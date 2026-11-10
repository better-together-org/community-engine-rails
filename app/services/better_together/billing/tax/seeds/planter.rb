# frozen_string_literal: true

module BetterTogether
  module Billing
    module Tax
      module Seeds
        # Plants a tax seed packet on a platform: tax categories, a zone for each place the packet names, and the rates
        # in force there. A packet is a Seed envelope in config/seeds/better_together/billing/<identifier>.yml, the same
        # format the seed catalog and the Seed model use for every other packet. Planting records the packet as a Seed
        # row (so it is versioned and can be exported) and then applies its payload.
        #
        # Zones are tied to the seeded geography rows by their ISO codes (the packet names `CA-NL`; the zone keeps the
        # State row), so the geography has to be planted first; a packet that names a place not found raises Missing and
        # plants nothing. It only adds what is missing and never changes a rate that exists (a rate that moves is a new
        # row with its own dates, so orders already placed keep the rate they were charged).
        #
        # A packet entry can give a `settlement_identifier` instead of a state, which makes it a municipal zone. No
        # packet that ships does so yet.
        class Planter
          PACKETS_DIR = BetterTogether::Engine.root.join('config/seeds/better_together/billing')

          class Missing < StandardError; end

          # The packets that ship with the engine, by identifier.
          def self.identifiers = PACKETS_DIR.glob('*.yml').map { |path| path.basename('.yml').to_s }.sort

          def self.call(platform:, identifier:) = new(platform, identifier).call

          # True when every zone the packet names is on the platform already.
          def self.planted?(platform:, identifier:) = new(platform, identifier).planted?

          def initialize(platform, identifier)
            @platform = platform
            @identifier = identifier.to_s
          end

          def call
            ::ActiveRecord::Base.transaction do
              Seed.import_or_update!(packet)
              tax[:categories].each { |category| plant_category(category) }
              tax[:zones].each { |zone| plant_zone(zone) }
            end
          end

          def planted?
            tax[:zones].all? do |entry|
              row = zone_for(entry)
              row && Billing::TaxZone.exists?(platform:, **place_of(row))
            end
          end

          private

          attr_reader :platform, :identifier

          def packet
            @packet ||= begin
              raise Missing, "No tax packet named '#{identifier}'" unless self.class.identifiers.include?(identifier)

              Seed.safe_load_yaml_file(PACKETS_DIR.join("#{identifier}.yml").to_s)
            end
          end

          def tax = @tax ||= packet.fetch(Seed::DEFAULT_ROOT_KEY).deep_symbolize_keys.fetch(:tax)

          def country
            @country ||= Geography::Country.find_by(iso_code: tax.fetch(:country_iso_code)) ||
                         raise(Missing, "Country #{tax.fetch(:country_iso_code)} is not planted (plant the geography countries first)")
          end

          def plant_category(entry)
            Billing::TaxCategory.find_or_create_by!(platform:, identifier: entry.fetch(:identifier)) do |category|
              assign_translations(category, :name, entry.fetch(:name))
              category.taxable = entry.fetch(:taxable)
            end
          end

          def plant_zone(entry)
            row = zone_for(entry) || raise(Missing, "#{entry[:settlement_identifier] || entry[:state_iso_code]} is not planted " \
                                                    '(plant the geography first)')
            zone = Billing::TaxZone.find_or_create_by!(platform:, **place_of(row)) { |new_zone| assign_translations(new_zone, :name, entry.fetch(:name)) }
            entry.fetch(:rates).each { |rate| plant_rate(zone, rate) }
          end

          def plant_rate(zone, entry)
            labels = translations_of(entry.fetch(:label))
            existing = I18n.with_locale(:en) do
              Billing::TaxRate.i18n.find_by(platform:, tax_zone: zone, label: labels.fetch(:en), discarded_at: nil)
            end
            existing || Billing::TaxRate.create!(platform:, tax_zone: zone, rate: BigDecimal(entry.fetch(:rate))) do |tax_rate|
              assign_translations(tax_rate, :label, labels)
            end
          end

          # A plain string is the English value.
          def translations_of(value) = value.is_a?(Hash) ? value : { en: value.to_s }

          # A packet value is a hash by locale; locales this app does not support are skipped.
          def assign_translations(record, attribute, values)
            translations_of(values).each do |locale, value|
              record.public_send(:"#{attribute}=", value, locale: locale.to_sym) if I18n.available_locales.include?(locale.to_sym)
            end
          end

          # The geography row a packet entry stands for: its settlement, else its state, else the country.
          def zone_for(entry)
            if entry[:settlement_identifier]
              Geography::Settlement.find_by(identifier: entry[:settlement_identifier])
            elsif entry[:state_iso_code]
              Geography::State.find_by(iso_code: entry[:state_iso_code])
            else
              country
            end
          end

          def place_of(row)
            case row
            when Geography::Settlement then { country: row.country || row.state&.country, state: row.state, settlement: row }
            when Geography::State then { country: row.country, state: row, settlement: nil }
            else { country: row, state: nil, settlement: nil }
            end
          end
        end
      end
    end
  end
end
