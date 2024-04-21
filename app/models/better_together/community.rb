# frozen_string_literal: true

module BetterTogether
  # A gathering
  class Community < ApplicationRecord
    include Identifier
    include Protected
    include Privacy
    include Permissible

    belongs_to :creator,
               class_name: '::BetterTogether::Person',
               optional: true

    slugged :name

    translates :name
    translates :description, type: :text

    validates :name,
              presence: true
    validates :description,
              presence: true

    validate :single_host_record

    def to_s
      name
    end

    # Method to set the host attribute to true only if there is no host community
    def set_as_host
      return if self.class.where(host: true).exists?

      self.host = true
    end

    private

    # Validate that only one COmmunity can be marked as host
    def single_host_record
      return unless host && self.class.where.not(id:).exists?(host: true)

      errors.add(:host, 'can only be set for one community')
    end
  end
end
