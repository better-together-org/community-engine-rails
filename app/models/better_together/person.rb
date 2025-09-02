# frozen_string_literal: true

require 'storext'

module BetterTogether
  # A human being
  class Person < ApplicationRecord # rubocop:todo Metrics/ClassLength
    def self.primary_community_delegation_attrs
      []
    end

    include Author
    include Contactable
    include FriendlySlug
    include HostsEvents
    include Identifier
    include Identity
    include Member
    include PrimaryCommunity
    include Privacy
    include Viewable
    include Metrics::Viewable
    include ::Storext.model

    has_community

    has_many :conversation_participants, dependent: :destroy
    has_many :conversations, through: :conversation_participants
    has_many :created_conversations, as: :creator, class_name: 'BetterTogether::Conversation', dependent: :destroy

    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreements, through: :agreement_participants

    has_many :person_blocks, foreign_key: :blocker_id, dependent: :destroy, class_name: 'BetterTogether::PersonBlock'
    has_many :blocked_people, through: :person_blocks, source: :blocked
    has_many :blocked_by_person_blocks, foreign_key: :blocked_id, dependent: :destroy, class_name: 'BetterTogether::PersonBlock'
    has_many :blockers, through: :blocked_by_person_blocks, source: :blocker

    has_many :reports_made, foreign_key: :reporter_id, class_name: 'BetterTogether::Report', dependent: :destroy
    has_many :reports_received, as: :reportable, class_name: 'BetterTogether::Report', dependent: :destroy

    has_many :notifications, as: :recipient, dependent: :destroy, class_name: 'Noticed::Notification'
    has_many :notification_mentions, as: :record, dependent: :destroy, class_name: 'Noticed::Event'

    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreements, through: :agreement_participants

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

    slugged :identifier, use: %i[slugged mobility], dependent: :delete_all

    store_attributes :preferences do
      locale String, default: I18n.default_locale.to_s
      time_zone String, default: ENV.fetch('APP_TIME_ZONE', 'Newfoundland')
      receive_messages_from_members Boolean, default: false
    end

    store_attributes :notification_preferences do
      notify_by_email Boolean, default: true
      show_conversation_details Boolean, default: false
    end

    # Ensure boolean coercion for form submissions ("0"/"1"), regardless of underlying store casting
    def notify_by_email=(value)
      prefs = (notification_preferences || {}).dup
      prefs['notify_by_email'] = ActiveModel::Type::Boolean.new.cast(value)
      self.notification_preferences = prefs
    end

    def show_conversation_details=(value)
      prefs = (notification_preferences || {}).dup
      prefs['show_conversation_details'] = ActiveModel::Type::Boolean.new.cast(value)
      self.notification_preferences = prefs
    end

    validates :name,
              presence: true

    translates :description_html, backend: :action_text

    # Return email from user if available, otherwise from contact details
    def email
      return user.email if user&.email.present?

      # Fallback to primary email address from contact details
      email_addresses.find(&:primary_flag)&.email
    end

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

    def description_html(locale: I18n.locale)
      super || description
    end

    def valid_event_host_ids
      [id] + member_communities.pluck(:id)
    end

    def handle
      identifier
    end

    def select_option_title
      "#{name} - @#{handle}"
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
