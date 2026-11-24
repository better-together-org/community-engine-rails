# frozen_string_literal: true

module BetterTogether
  # Which packet planted a record, under what key, and what the record looked like right after.
  class SeedProvenance < ApplicationRecord
    self.table_name = 'better_together_seed_provenances'

    belongs_to :platform, class_name: 'BetterTogether::Platform'
    belongs_to :seed, class_name: 'BetterTogether::Seed', optional: true
    belongs_to :seed_planting, class_name: 'BetterTogether::SeedPlanting', optional: true

    validates :packet_id, :record_type, :record_key, :record_class, :record_id, :fingerprint, presence: true

    scope :for_packet, ->(platform:, packet_id:) { where(platform:, packet_id:) }

    # The provenance of a planted record, or nil when no packet planted it.
    def self.for_record(record)
      find_by(record_class: record.class.base_class.name, record_id: record.id)
    end
  end
end
