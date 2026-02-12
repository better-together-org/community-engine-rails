# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the Community class
      class CommunityResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Community'

        # Translated attributes
        attributes :name, :description

        # Standard attributes
        attributes :slug, :identifier, :privacy, :protected, :host

        # Virtual attributes for attachments
        attribute :profile_image_url
        attribute :cover_image_url
        attribute :logo_url

        # Relationships
        has_one :creator, class_name: 'Person'
        has_many :members, class_name: 'Person'
        has_many :person_community_memberships
        # TODO: Enable when corresponding resources are created
        # has_many :calendars

        # Filters
        filter :privacy
        filter :protected
        filter :host
        filter :creator_id

        # Custom attribute methods
        def profile_image_url
          attachment_url(:profile_image)
        end

        def cover_image_url
          attachment_url(:cover_image)
        end

        def logo_url
          attachment_url(:logo)
        end

        # Fetchable fields (customize what's available to query)
        def self.fetchable_fields(context)
          super - [:protected] # Don't allow filtering by protected unless admin
        end

        # Creatable and updatable fields
        def self.creatable_fields(context)
          super - %i[slug protected host] # These are system-managed
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end
      end
    end
  end
end
