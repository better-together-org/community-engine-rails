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
      metadata = data.fetch(:seed)
      payload = data.except(:version, :seed)

      record = find_or_initialize_by(
        type: metadata.fetch(:type, name),
        identifier: metadata.fetch(:identifier)
      )

      record.assign_attributes(
        version: data.fetch(:version),
        created_by: metadata.fetch(:created_by),
        seeded_at: Time.iso8601(metadata.fetch(:created_at)),
        description: metadata.fetch(:description),
        origin: metadata.fetch(:origin),
        payload: payload,
        seedable_type: metadata[:seedable_type],
        seedable_id: metadata[:seedable_id]
      )
      record.save!
      record
    end
  end
end
