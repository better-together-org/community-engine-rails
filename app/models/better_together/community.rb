# frozen_string_literal: true

module BetterTogether
  # A gathering
  class Community < ApplicationRecord
    PRIVACY_LEVELS = {
      secret: 'secret',
      closed: 'closed',
      public: 'public'
    }.freeze

    include Identifier
    include Protected

    belongs_to :creator,
               class_name: '::BetterTogether::Person',
               optional: true

    enum privacy: PRIVACY_LEVELS,
         _prefix: :privacy

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
      return if BetterTogether::Community.where(host: true).exists?

      self.host = true
    end

    private

    # Validate that only one COmmunity can be marked as host
    def single_host_record
      return unless host && BetterTogether::Community.where.not(id:).exists?(host: true)

      errors.add(:host, 'can only be set for one community')
    end
  end
end
