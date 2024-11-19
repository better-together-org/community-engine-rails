# frozen_string_literal: true

module BetterTogether
  module PagesHelper # rubocop:todo Style/Documentation
    def render_page_content page
      Rails.cache.fetch(['page_content', I18n.locale, page.identifier, page.updated_at.to_i], expires_in: 1.minute) do
        render @page.content_blocks
      end
    end
  end
end
