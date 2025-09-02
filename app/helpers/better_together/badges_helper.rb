# frozen_string_literal: true

module BetterTogether
  # Helpers for Badges
  module BadgesHelper
    def categories_badge(entity, rounded: true, style: 'info')
      return unless entity.respond_to?(:categories) && entity.categories.any?

      safe_join(
        entity.categories.map { |category| create_badge(category.name, rounded: rounded, style: style) },
        ' '
      )
    end

    # Render a privacy badge for an entity.
    # By default, map known privacy values to sensible Bootstrap context classes.
    # Pass an explicit `style:` to force a fixed Bootstrap style instead of using the mapping.
    def privacy_badge(entity, rounded: true, style: nil)
      return unless entity.respond_to?(:privacy) && entity.privacy.present?

      privacy_key = entity.privacy.to_s.downcase

      # Map privacy values to Bootstrap text-bg-* styles. Consumers can override by passing `style:`.
      privacy_style_map = {
        'public' => 'success',
        'private' => 'secondary',
        'community' => 'info'
      }

      chosen_style = style || privacy_style_map[privacy_key] || 'primary'

      create_badge(entity.privacy.humanize.capitalize, rounded: rounded, style: chosen_style)
    end

    # Return the mapped bootstrap-style for an entity's privacy. Useful for wiring
    # styling elsewhere (for example: tinting checkboxes to match privacy badge).
    def privacy_style(entity)
      return nil unless entity.respond_to?(:privacy) && entity.privacy.present?

      privacy_key = entity.privacy.to_s.downcase
      privacy_style_map = {
        'public' => 'success',
        'private' => 'secondary',
        'community' => 'info'
      }

      privacy_style_map[privacy_key] || 'primary'
    end

    private

    def create_badge(label, rounded: true, style: 'primary')
      rounded_class = rounded ? 'rounded-pill' : ''
      style_class = "text-bg-#{style}"

      content_tag :span, label, class: "badge #{rounded_class} #{style_class}"
    end
  end
end
