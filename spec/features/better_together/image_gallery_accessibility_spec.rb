# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'image gallery accessibility', :accessibility, :js, retry: 0 do
  include ImageGalleryHelpers

  before { configure_host_platform }

  %w[grid masonry].each do |layout|
    it "has no axe violations in the #{layout} layout" do
      page_record = build_gallery_page
      visit better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale,
                                             **gallery_params(layout))

      expect(page).to have_css('.image-gallery img', minimum: 4)
      expect(page).to be_axe_clean.within('.image-gallery')
    end
  end
end
