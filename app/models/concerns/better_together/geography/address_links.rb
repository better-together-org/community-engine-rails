# frozen_string_literal: true

module BetterTogether
  module Geography
    # Optional links from an Address to the geography records it was entered against.
    # A chosen record is authoritative and overwrites the matching string column; the string
    # columns stay as the free-text fallback for places that are not (yet) geography records.
    module AddressLinks
      extend ActiveSupport::Concern

      # level => string column holding the name
      STRING_COLUMNS = { country: :country_name, state: :state_province_name, settlement: :city_name }.freeze

      included do
        belongs_to :country, class_name: 'BetterTogether::Geography::Country', optional: true
        belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true
        belongs_to :settlement, class_name: 'BetterTogether::Geography::Settlement', optional: true

        before_validation :sync_geography_strings
        validate :geography_is_consistent

        # Locatable::Many defines same-named readers (resolved placements) that would shadow the
        # belongs_to readers, so prefer the explicit link and fall back to the resolved placement.
        STRING_COLUMNS.each_key do |level|
          define_method(level) { association(level).reader || super() }
        end
      end

      private

      # The explicit link only; the public readers fall back to resolved placements, which
      # validation must not consult (it would also load locatable_locations early).
      def linked(level)
        association(level).reader
      end

      # A chosen settlement implies its state and country, a chosen state its country; then the
      # chosen records overwrite the string columns.
      def sync_geography_strings
        derive_parent_links
        STRING_COLUMNS.each do |level, column|
          record = linked(level)
          self[column] = record.name if record
        end
      end

      # A parent is derived from a chosen child only when the user has not typed something else for it;
      # a typed parent that disagrees with the child is a validation error, never silently replaced.
      def derive_parent_links
        derive_parent(:state)
        derive_parent(:country)
      end

      def derive_parent(level)
        expected = expected_parent(level)
        return if expected.nil? || self["#{level}_id"].present? || !typed_matches?(level, expected)

        public_send("#{level}=", expected)
      end

      def expected_parent(level)
        return linked(:settlement)&.state if level == :state

        linked(:state)&.country || linked(:settlement)&.country
      end

      def typed_matches?(level, record)
        typed = self[STRING_COLUMNS[level]].to_s.strip
        typed.blank? || typed.casecmp?(record.name.to_s)
      end

      def geography_is_consistent
        errors.add(:state_id, :inclusion) if linked(:state) && country_id && linked(:state).country_id != country_id
        errors.add(:settlement_id, :inclusion) if linked(:settlement) && settlement_outside_parents?
        %i[state country].each { |level| validate_typed_parent(level) }
      end

      def validate_typed_parent(level)
        expected = expected_parent(level)
        return if expected.nil? || self["#{level}_id"].present? || typed_matches?(level, expected)

        errors.add(STRING_COLUMNS[level], I18n.t('errors.models.address_geography_conflict', selected: expected.name))
      end

      def settlement_outside_parents?
        mismatched = ->(parent_id, settlement_parent_id) { parent_id && settlement_parent_id && parent_id != settlement_parent_id }
        settlement = linked(:settlement)
        mismatched.call(state_id, settlement.state_id) || mismatched.call(country_id, settlement.country_id)
      end
    end
  end
end
