# frozen_string_literal: true

require 'storext'

module BetterTogether
  # A human being
  class Person < ApplicationRecord
    def self.primary_community_delegation_attrs
      []
    end

    include AuthorConcern
    include Contactable
    include FriendlySlug
    include Identifier
    include Identity
    include Member
    include PrimaryCommunity
    include Privacy
    include ::Storext.model

    has_many :conversation_participants, dependent: :destroy
    has_many :conversations, through: :conversation_participants
    has_many :created_conversations, as: :creator, class_name: 'BetterTogether::Conversation', dependent: :destroy

    has_many :notifications, as: :recipient, dependent: :destroy, class_name: 'Noticed::Notification'
    has_many :notification_mentions, as: :record, dependent: :destroy, class_name: 'Noticed::Event'

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

    validates :name,
              presence: true

    delegate :email, to: :user, allow_nil: true

    has_one_attached :profile_image
    has_one_attached :cover_image

    # Resize the profile image before rendering
    def profile_image_variant(size)
      profile_image.variant(resize_to_fill: [size, size]).processed
    end

    # Resize the cover image to specific dimensions
    def cover_image_variant(width, height)
      cover_image.variant(resize_to_fill: [width, height]).processed
    end

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

    include ::BetterTogether::RemoveableAttachment
  end
end
