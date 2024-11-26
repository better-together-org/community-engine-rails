# frozen_string_literal: true

module BetterTogether
  module PagesHelper
    def render_page_content(page)
      Rails.cache.fetch(['page_content', page.cache_key_with_version], expires_in: 1.minute) do
        render @page.content_blocks
      end
    end
  end
end
