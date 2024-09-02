# frozen_string_literal: true

require 'storext'

module BetterTogether
  # A human being
  class Person < ApplicationRecord
    def self.primary_community_delegation_attrs
      []
    end

    include AuthorConcern
    include FriendlySlug
    include Identifier
    include Identity
    include Member
    include PrimaryCommunity
    include ::Storext.model

    has_many :conversation_participants, dependent: :destroy
    has_many :conversations, through: :conversation_participants
    has_many :created_conversations, as: :creator, class_name: 'BetterTogether::Conversation', dependent: :destroy

    has_one :user_identification,
            lambda {
              where(
                agent_type: 'BetterTogether::User',
                active: true
              )
            },
            as: :identity,
            class_name: 'BetterTogether::Identification'

    has_one :user,
            through: :user_identification,
            source: :agent,
            source_type: 'BetterTogether::User'

    member member_type: 'person',
           joinable_type: 'community'

    member member_type: 'person',
           joinable_type: 'platform'

    slugged :identifier, dependent: :delete_all

    store_attributes :preferences do
      locale String, default: I18n.default_locale.to_s
      time_zone String, default: ENV.fetch('APP_TIME_ZONE', 'Newfoundland')
    end

    # has_one_attached :profile_image

    validates :name,
              presence: true

    delegate :email, to: :user, allow_nil: true

    # validate :validate_profile_image

    def to_s
      name
    end

    def primary_community_extra_attrs
      { protected: true }
    end

    def after_record_created
      return unless community

      community.update!(creator_id: id)
    end

    # def validate_profile_image
    #   return unless profile_image.attached?

    #   if profile_image.blob.byte_size > 5.megabytes
    #     errors.add(:profile_image, 'is too large (maximum is 5MB)')
    #   elsif !profile_image.blob.content_type.starts_with?('image/')
    #     errors.add(:profile_image, 'is not an image')
    #   else
    #     validate_image_dimensions
    #   end
    # end

    # def validate_image_dimensions
    #   return unless Object.const_defined?('MiniMagick')

    #   image = MiniMagick::Image.open(profile_image.blob.service_url)
    #   if image.width > 3000 || image.height > 3000
    #     errors.add(:profile_image, 'dimensions are too large (maximum is 3000x3000 pixels)')
    #   end
    # end
  end
end
