# frozen_string_literal: true

require 'storext'

module BetterTogether
  # Represents the host application and it's peers
  class Platform < ApplicationRecord
    include Identifier
    include Host
    include Joinable
    include Permissible
    include PrimaryCommunity
    include Privacy
    include Protected
    include ::Storext.model

    joinable joinable_type: 'platform',
             member_type: 'person'

    has_many :invitations,
             class_name: '::BetterTogether::PlatformInvitation',
             foreign_key: :invitable_id

    slugged :name

    store_attributes :settings do
      requires_invitation Boolean, default: false
    end

    validates :url, presence: true, uniqueness: true
    validates :time_zone, presence: true

    def primary_community_extra_attrs
      { host:, protected: }
    end

    def to_s
      name
    end
  end
end
