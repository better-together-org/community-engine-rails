# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a BetterTogether::NavigationArea with its navigation items
    class NavigationAreaBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes

      store_attributes :content_data do
        navigation_area_id String, default: ''
      end

      validates :navigation_area_id, presence: true

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[navigation_area_id]
      end

      def navigation_area
        return nil if navigation_area_id.blank?

        BetterTogether::NavigationArea.find_by(id: navigation_area_id)
      end
    end
  end
end
