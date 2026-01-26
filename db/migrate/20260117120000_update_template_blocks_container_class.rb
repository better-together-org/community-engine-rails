# frozen_string_literal: true

# Updates template block container classes to the new layout utility
class UpdateTemplateBlocksContainerClass < ActiveRecord::Migration[7.1]
  def up
    BetterTogether::Content::Template
      .joins(:pages)
      .where(better_together_pages: { layout: 'layouts/better_together/full_width_page' })
      .find_each do |template|
        next unless template.container_class.blank? || template.container_class == 'container'

        template.update_columns(
          css_settings: template.css_settings.merge('container_class' => '')
        )
      end
  end

  def down
    # No-op: only adjusts styling; safe to leave as-is
  end
end
