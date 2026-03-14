# frozen_string_literal: true

module BetterTogether
  module Content
    # Shared store_attributes and helpers for resource collection block types.
    # Included by all blocks that render dynamic collections of BT records.
    module ResourceBlockAttributes
      extend ActiveSupport::Concern

      included do
        store_attributes :content_data do
          display_style    String,  default: 'grid'
          item_limit       Integer, default: 6
          resource_ids     String,  default: ''
          community_scope_id String, default: ''
          show_view_more_link String, default: 'false'
          view_more_url String, default: ''
        end

        validates :display_style,
                  inclusion: { in: %w[grid list], message: 'must be grid or list' },
                  allow_blank: false

        validates :item_limit,
                  numericality: { greater_than: 0, less_than_or_equal_to: 50 },
                  allow_nil: false
      end

      # Returns an array of UUIDs if resource_ids is populated, else [].
      def parsed_resource_ids
        return [] if resource_ids.blank?

        JSON.parse(resource_ids)
      rescue JSON::ParserError
        resource_ids.split(',').map(&:strip).reject(&:blank?)
      end

      def scoped_community
        return nil if community_scope_id.blank?

        BetterTogether::Community.find_by(id: community_scope_id)
      end

      def show_view_more?
        show_view_more_link == 'true' && view_more_url.present?
      end

      def self.extra_permitted_attributes
        %i[display_style item_limit resource_ids community_scope_id show_view_more_link view_more_url]
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods # rubocop:disable Style/Documentation
        def extra_permitted_attributes
          super + ResourceBlockAttributes.extra_permitted_attributes
        end
      end
    end
  end
end
