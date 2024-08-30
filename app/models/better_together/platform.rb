# frozen_string_literal: true

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

    joinable joinable_type: 'platform',
             member_type: 'person'

    has_many :invitations,
             class_name: '::BetterTogether::PlatformInvitation',
             foreign_key: :invitable_id

    slugged :name

    validates :url, presence: true, uniqueness: true
    validates :time_zone, presence: true

    def primary_community_extra_attrs
      { host:, protected: }
    end

    def to_s
      name
    end

    # def url
    #   "#{super}/#{I18n.locale}/"
    # end
  end
end
