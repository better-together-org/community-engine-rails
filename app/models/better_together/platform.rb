# frozen_string_literal: true

module BetterTogether
  # Represents the host application and it's peers
  class Platform < ApplicationRecord
    PRIVACY_LEVELS = {
      secret: 'secret',
      closed: 'closed',
      public: 'public'
    }.freeze

    include Identifier
    include Protected
    
    belongs_to :community, class_name: '::BetterTogether::Community', optional: true
    
    enum privacy: PRIVACY_LEVELS,
         _prefix: :privacy
    
    slugged :name

    translates :name
    translates :description, type: :text

    validates :name, presence: true
    validates :description, presence: true
    validates :url, presence: true, uniqueness: true
    validates :time_zone, presence: true

    validate :single_host_record

    def to_s
      name
    end

    # Method to set the host attribute to true only if there is no host platform
    def set_as_host
      return if self.class.where(host: true).any?

      self.host = true
    end

    # Method to build the host platform's community
    def build_host_community
      # Return immediately if this platform is not set as a host
      return unless host

      # Build the associated community with matching attributes
      community = build_community(name:, description:, privacy:)
      community.set_as_host

      community
    end

    private

    # Validate that only one Platform can be marked as host
    def single_host_record
      return unless host && self.class.where.not(id:).exists?(host: true)

      errors.add(:host, 'can only be set for one platform')
    end
  end
end
