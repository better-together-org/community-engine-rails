# frozen_string_literal: true

module BetterTogether
  module Geography
    # Links existing addresses to the geography records already resolved for them as
    # placements (HierarchyResolutionJob). Only fills empty links, never overwrites one,
    # and uses update_columns so no callbacks, geocoding or timestamps fire. Idempotent.
    class AddressLinkBackfill
      COLUMNS = { country: :country_id, state: :state_id, settlement: :settlement_id }.freeze

      def self.call(scope: BetterTogether::Address.all)
        new(scope).call
      end

      def initialize(scope)
        @scope = scope
      end

      def call
        linked = 0
        @scope.where(country_id: nil).or(@scope.where(state_id: nil)).or(@scope.where(settlement_id: nil))
              .includes(:locatable_locations).find_each do |address|
          linked += apply_links(address)
        end
        { linked: }
      end

      private

      def apply_links(address)
        attrs = COLUMNS.filter_map do |level, column|
          next if address[column]

          record = placement(address, level)
          [column, record.id] if record
        end.to_h
        return 0 if attrs.empty?

        address.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
        1
      end

      def placement(address, level)
        klass = BetterTogether::Geography::Locatable::Many::LEVELS.fetch(level)
        address.locatable_locations.find { |ll| ll.location_type == klass.name }&.location
      end
    end
  end
end
