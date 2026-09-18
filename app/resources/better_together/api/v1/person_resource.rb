# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the Person class
      class PersonResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Person'

        # Basic attributes
        attributes :name, :slug, :identifier, :privacy

        # Virtual attributes
        attribute :handle
        attribute :email

        # Preference attributes
        attribute :locale
        attribute :time_zone
        attribute :receive_messages_from_members
        attribute :federate_content

        # Notification preference attributes
        attribute :notify_by_email
        attribute :show_conversation_details

        # Attachment URLs
        attribute :profile_image_url
        attribute :cover_image_url

        # Relationships
        has_one :user
        has_many :communities, relation_name: :member_communities
        has_many :person_community_memberships
        # TODO: Enable when corresponding resources are created
        # has_many :person_blocks
        # has_many :blocked_people, class_name: 'Person'
        # `has_many :conversations` (ConversationResource already exists) was tried and
        # reverted: enabling it makes the relationships/related/include=conversations
        # endpoints all return wrong data — conversation_participants join-row ids
        # mislabeled as `conversations`, or empty resource objects — a pre-existing
        # JSONAPI::Resources resolution bug for this has_many-through shape, not a
        # config typo. Needs its own root-cause fix before re-enabling.
        # has_many :conversations

        # Filters
        filter :privacy
        filter :locale
        filter :identifier

        # Custom attribute methods
        def handle
          @model.identifier
        end

        def email
          @model.email
        end

        def locale
          @model.locale
        end

        def time_zone
          @model.time_zone
        end

        def receive_messages_from_members
          @model.receive_messages_from_members
        end

        def federate_content
          @model.federate_content
        end

        def notify_by_email
          @model.notify_by_email
        end

        def show_conversation_details
          @model.show_conversation_details
        end

        def profile_image_url
          attachment_url(:profile_image)
        end

        def cover_image_url
          attachment_url(:cover_image)
        end

        # Creatable and updatable fields
        def self.creatable_fields(context)
          super - %i[slug handle] # These are derived/system-managed
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end

        # Only expose email when the requesting user's person is available in context
        def fetchable_fields
          fields = super
          unless context[:current_person].present?
            fields -= [:email]
          end
          fields
        end
      end
    end
  end
end
