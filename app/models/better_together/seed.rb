# frozen_string_literal: true

module BetterTogether
  # Canonical CE data envelope for portable export/import between platforms.
  class Seed < ApplicationRecord
    self.table_name = 'better_together_seeds'
    self.inheritance_column = :type

    DEFAULT_ROOT_KEY = 'better_together'

    include Creatable
    include Identifier
    include Privacy

    belongs_to :seedable, polymorphic: true, optional: true

    validates :type, :identifier, :version, :created_by, :seeded_at, :description, :origin, :payload, presence: true

    scope :latest_first, -> { order(seeded_at: :desc, created_at: :desc) }
    scope :by_identifier, ->(identifier) { where(identifier:) }

    def origin
      super&.with_indifferent_access || {}
    end

    def payload
      super&.with_indifferent_access || {}
    end

    def payload_data
      payload[:payload].presence || payload
    end

    def lane
      origin[:lane].presence || payload_data[:lane]
    end

    def private_linked?
      lane == 'private_linked'
    end

    def platform_shared?
      lane == 'platform_shared'
    end

    def self.import_or_update!(seed_data, root_key: DEFAULT_ROOT_KEY)
      data = seed_data.deep_symbolize_keys.fetch(root_key.to_sym)
      record = find_or_build_from_data(data)
      record.assign_attributes(seed_record_attributes(data))
      record.save!
      record
    end

    def self.find_or_build_from_data(data)
      metadata = data.fetch(:seed)
      find_or_initialize_by(
        type: metadata.fetch(:type, name),
        identifier: metadata.fetch(:identifier)
      )
    end

    def self.seed_record_attributes(data)
      metadata = data.fetch(:seed)
      {
        version: data.fetch(:version),
        created_by: metadata.fetch(:created_by),
        seeded_at: Time.iso8601(metadata.fetch(:created_at)),
        description: metadata.fetch(:description),
        origin: metadata.fetch(:origin),
        payload: data.except(:version, :seed),
        seedable_type: metadata[:seedable_type],
        seedable_id: metadata[:seedable_id]
      }
    end
  end
end
