# frozen_string_literal: true

module BetterTogether
  # Represents the host application and it's peers
  class Platform < ApplicationRecord
    include Identifier
    include Host
    include Joinable
    include Permissible
    include Privacy
    include Protected

    joinable joinable_type: 'platform',
             member_type: 'person'
    
    belongs_to :community, class_name: '::BetterTogether::Community', optional: true

    slugged :name

    translates :name
    translates :description, type: :text

    validates :name, presence: true
    validates :description, presence: true
    validates :url, presence: true, uniqueness: true
    validates :time_zone, presence: true

    def to_s
      name
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
  end
end
