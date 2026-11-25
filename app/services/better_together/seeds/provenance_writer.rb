# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Stores the Seed envelope row for a plant (one per platform) and one SeedProvenance row per record the
    # plant wrote or removed. Runs inside the plant transaction, so it commits or rolls back with the records.
    class ProvenanceWriter
      def self.call(...)
        new(...).call
      end

      def initialize(packet:, platform:, planting:, provenance:)
        @packet = packet
        @platform = platform
        @planting = planting
        @provenance = provenance
      end

      def call
        seed = store_seed
        provenance.each { |id, data| record(id, data, seed) }
        seed
      end

      private

      attr_reader :packet, :platform, :planting, :provenance

      def store_seed
        seed = ::BetterTogether::Seed.import_or_update!(seed_data, platform:)
        planting.update!(seed:)
        seed
      end

      # The envelope without the per-record files, which can be megabytes; the records live in their own tables.
      def seed_data
        envelope = packet.envelope
        { better_together: {
          version: envelope['version'].to_s, seed: seed_meta(envelope.fetch('seed', {})),
          seed_pack: envelope['seed_pack'], packet: packet.packet_meta.except('records')
        } }
      end

      def seed_meta(meta)
        defaults = { 'type' => 'BetterTogether::Seed', 'created_by' => 'seed packet', 'created_at' => Time.current.iso8601,
                     'description' => packet.identifier, 'origin' => { 'packet' => packet.identifier } }
        defaults.merge(meta.compact_blank).merge('identifier' => packet.identifier).symbolize_keys
      end

      def record(id, data, seed)
        type, key = id.split(':', 2)
        scope = SeedProvenance.for_packet(platform:, packet_id: packet.identifier).where(record_type: type, record_key: key)
        return scope.delete_all if data['deleted']

        scope.first_or_initialize.update!(row_attributes(type, data).merge(seed:, seed_planting: planting))
      end

      def row_attributes(type, data)
        { packet_version: packet.packet_meta['version'], record_class: Registry.fetch(type).model.base_class.name,
          record_id: data['id'], fingerprint: Snapshot.fingerprint(data['snapshot']), snapshot: data['snapshot'] }
      end
    end
  end
end
