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

    # Get the translated display value for a privacy setting
    def privacy_display_value(entity)
      return '' unless entity.respond_to?(:privacy) && entity.privacy.present?

      privacy_key = entity.privacy.to_s.downcase
      t("attributes.privacy_list.#{privacy_key}", default: entity.privacy.humanize.capitalize)
    end

    # Render a privacy badge for an entity.
    # By default, map known privacy values to sensible Bootstrap context classes.
    # Pass an explicit `style:` to force a fixed Bootstrap style instead of using the mapping.
    # rubocop:disable Metrics/MethodLength
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
      privacy_label = privacy_display_value(entity)
      tooltip_text = t('better_together.shared.privacy_tooltip', privacy: privacy_label)

      create_badge(
        privacy_label,
        rounded: rounded,
        style: chosen_style,
        tooltip: tooltip_text,
        aria_label: t('better_together.shared.privacy_level', privacy: privacy_label)
      )
    end
    # rubocop:enable Metrics/MethodLength

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

    def create_badge(label, rounded: true, style: 'primary', tooltip: nil, aria_label: nil)
      rounded_class = rounded ? 'rounded-pill' : ''
      style_class = "text-bg-#{style}"

      options = { class: "badge #{rounded_class} #{style_class} icon-above-stretched-link" }
      options['data-bs-toggle'] = 'tooltip' if tooltip
      options[:title] = tooltip if tooltip
      options['aria-label'] = aria_label if aria_label

      content_tag :span, label, options
    end
  end
end
