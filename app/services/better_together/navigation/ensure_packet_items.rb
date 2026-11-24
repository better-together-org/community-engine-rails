# frozen_string_literal: true

module BetterTogether
  module Navigation
    # Adds the navigation items the default navigation packet lists but a platform does not have yet.
    # Items are matched by identifier within the platform's navigation area and are never changed once
    # they exist, so a steward's edits stand. The one exception is moving a legacy billing item from
    # the Host menu into the Billing menu. Safe to run any number of times; run it from a migration
    # whenever the packet or the route name list gains an item, so every host app picks it up on deploy.
    class EnsurePacketItems
      RECORDS_PATH = BetterTogether::Engine.root.join('config/seeds/better_together/navigation/records/navigation_items.yml')
      LEGACY_PARENT = 'host-nav'
      Change = Data.define(:identifier, :area, :action)

      def self.call(...) = new(...).call

      # areas: navigation area identifiers to keep in step with the packet (default: every area the packet fills).
      def initialize(dry_run: false, areas: nil)
        @dry_run = dry_run
        @area_identifiers = areas
      end

      def call
        changes = []
        BetterTogether::NavigationArea.where(identifier: area_identifiers).find_each do |area|
          next unless (area_records = records_by_area[area.identifier])

          ActiveRecord::Base.no_touching { changes.concat(ensure_area(area, area_records)) }
        end
        changes
      end

      private

      attr_reader :dry_run

      def area_identifiers = @area_identifiers || records_by_area.keys

      def records
        @records ||= YAML.safe_load_file(RECORDS_PATH).fetch('records')
      end

      def records_by_area
        @records_by_area ||= records.group_by { |record| record.dig('refs', 'navigation_area').to_s.split(':', 2).last }
                                    .select { |identifier, _| identifier == 'platform-host' || @area_identifiers&.include?(identifier) }
      end

      def ensure_area(area, area_records)
        items = BetterTogether::NavigationItem.where(navigation_area: area).index_by(&:identifier)
        area_records.filter_map { |record| ensure_record(area, items, record) }
      end

      def ensure_record(area, items, record)
        key = record.fetch('key')
        existing = items[key]
        parent = parent_for(items, record)
        return move_legacy(area, existing, parent, record) if existing
        return if record.dig('refs', 'parent') && parent.nil? && !dry_run

        create(area, items, key, parent, record) unless dry_run
        Change.new(key, area.identifier, :create)
      end

      def parent_for(items, record)
        parent_key = record.dig('refs', 'parent')&.split(':', 2)&.last
        items[parent_key] if parent_key
      end

      def move_legacy(area, item, parent, record)
        return unless parent && item.parent&.identifier == LEGACY_PARENT && parent.identifier != LEGACY_PARENT

        item.update!(parent:, position: free_position(area, parent, record['position'])) unless dry_run
        Change.new(item.identifier, area.identifier, :move)
      end

      # Positions are unique per parent. Keep the packet's position when it is free, else go last,
      # so an item a steward added in the same slot does not block the new one.
      def free_position(area, parent, wanted)
        siblings = BetterTogether::NavigationItem.where(navigation_area: area, parent:)
        return wanted unless wanted.nil? || siblings.exists?(position: wanted)

        siblings.maximum(:position).to_i + 1
      end

      def create(area, items, key, parent, record)
        item = BetterTogether::NavigationItem.new(record.fetch('attributes').merge(
                                                    identifier: key, navigation_area: area, parent:,
                                                    position: free_position(area, parent, record['position'])
                                                  ))
        record.fetch('translations', {}).each do |locale, fields|
          Mobility.with_locale(locale) { item.title = fields['title'] }
        end
        item.save!
        items[key] = item
      end
    end
  end
end
