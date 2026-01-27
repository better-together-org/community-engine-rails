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

        # Notification preference attributes
        attribute :notify_by_email
        attribute :show_conversation_details

        # Attachment URLs
        attribute :profile_image_url
        attribute :cover_image_url

        # Relationships
        has_one :user
        has_many :communities
        has_many :community_memberships
        # TODO: Enable when corresponding resources are created
        # has_many :conversations
        # has_many :person_blocks
        # has_many :blocked_people, class_name: 'Person'

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
      end
    end
  end
end
