# frozen_string_literal: true

module BetterTogether
  # Shares post index preload helpers across controller actions.
  module PostsIndexPreload
    private

    def post_includes
      resource_class.card_render_includes.reject do |entry|
        entry.is_a?(Hash) && entry[:contributions]
      end
    end

    def post_index_includes
      base_includes = [
        :string_translations,
        { categories: :string_translations },
        { contributions: { author: [:string_translations, { profile_image_attachment: :blob }] } }
      ]

      case @view_type
      when 'table'
        base_includes
      when 'list', 'calendar', 'map'
        base_includes + action_text_includes
      else
        base_includes + card_media_includes + action_text_includes
      end
    end

    def card_media_includes
      [
        { cover_image_attachment: :blob },
        { categories: { cover_image_attachment: :blob } }
      ]
    end

    def action_text_includes
      rich_text_association = resource_class.reflect_on_association(:rich_text_content)&.name
      rich_text_association ? [rich_text_association] : []
    end
  end
end
