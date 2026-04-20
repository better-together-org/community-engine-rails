# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Page
      # Exposes published pages with content blocks
      class PageResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Page'

        CONTRIBUTOR_ID_ATTRIBUTES = BetterTogether::Authorable::CONTRIBUTION_ROLE_CONFIG.keys.flat_map do |role_name|
          [role_name.to_sym, :"robot_#{role_name}"].map { |prefix| :"#{prefix}_ids" }
        end.freeze

        # Translated attributes
        translatable_attribute :title

        # Regular attributes
        attributes :slug, :privacy, :layout, :published_at
        attribute :show_title
        attribute :content_excerpt
        attribute :contributions_attributes
        CONTRIBUTOR_ID_ATTRIBUTES.each { |attribute_name| attribute attribute_name }

        # Relationships
        has_one :community
        has_one :creator, class_name: 'Person'
        has_one :sidebar_nav, class_name: 'NavigationArea'
        has_many :contributions, class_name: 'Authorship'
        has_many :page_blocks, class_name: 'PageBlock'
        has_many :blocks, class_name: 'Block'

        # Filters
        filter :privacy
        filter :layout
        filter :slug, apply: lambda { |records, value, _options|
          matching_ids = records.i18n.where(slug: Array(value)).pluck(:id)
          records.where(id: matching_ids)
        }

        def content_excerpt
          @model.content&.to_plain_text&.truncate(200)
        end

        def show_title
          @model.show_title
        end

        def contributions_attributes
          @model.contributions.map do |contribution|
            {
              id: contribution.id,
              author_id: contribution.author_id,
              author_type: contribution.author_type,
              role: contribution.role,
              contribution_type: contribution.contribution_type,
              position: contribution.position
            }
          end
        end

        def self.creatable_fields(_context)
          %i[
            title content slug privacy layout show_title published_at
            community creator sidebar_nav contributions
            contributions_attributes
          ] + CONTRIBUTOR_ID_ATTRIBUTES
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end
      end
    end
  end
end
