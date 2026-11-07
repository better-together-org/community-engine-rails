# frozen_string_literal: true

module BetterTogether
  module Weather
    # A configured weather data source. The adapter_key selects the adapter class
    # from Weather::Registry; config carries adapter specific settings.
    class Source < ApplicationRecord
      has_many :locations, class_name: 'BetterTogether::Weather::Location', dependent: :destroy

      validates :identifier, presence: true, uniqueness: true, length: { maximum: 100 }
      validates :adapter_key, presence: true
      validate :adapter_key_registered

      scope :enabled, -> { where(enabled: true) }

      def adapter
        Registry.build(adapter_key, config)
      end

      def self.extra_permitted_attributes
        super + %i[identifier adapter_key enabled]
      end

      private

      def adapter_key_registered
        return if adapter_key.blank? || Registry.registered?(adapter_key)

        errors.add(:adapter_key, :inclusion)
      end
    end
  end
end
