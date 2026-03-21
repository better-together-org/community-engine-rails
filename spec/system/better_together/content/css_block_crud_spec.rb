# frozen_string_literal: true

require 'rails_helper'

# Headed QA spec — run with SELENIUM_HEADLESS=0 and a human supervisor via noVNC.
# Covers: create, view, edit, delete of a Content::Css block via the admin UI.
# Also asserts the truncation regression: content > 255 chars must persist without clipping.
RSpec.describe 'Content::Css block CRUD', :as_platform_manager, :js do
  include BetterTogether::CapybaraFeatureHelpers

  let(:long_css) do
    # Build CSS > 255 chars to exercise the type:text migration regression
    rules = [
      '.leaflet-top, .leaflet-bottom { z-index: 999; }',
      '.notification form[action*="mark_as_read"] .btn[type="submit"] { z-index: 1200; }',
      '.card.journey-stage > .card-body { max-height: 50vh; overflow-y: auto; }',
      '@media only screen and (min-width: 768px) { .hero-heading { font-size: 3em; } }',
      '.custom-footer { background: #333; color: #fff; padding: 1rem 2rem; }'
    ]
    rules.join("\n")
  end

  before do
    configure_host_platform
    capybara_login_as_platform_manager
  end

  describe 'create a CssBlock with > 255 chars and verify no truncation' do
    it 'saves and reloads the full CSS content intact' do
      visit better_together.new_content_block_path(
        locale: I18n.default_locale,
        block_type: 'BetterTogether::Content::Css'
      )

      expect(page).to have_css('div.css-fields', wait: 10)

      # Fill the identifier
      fill_in 'block[identifier]', with: 'truncation-regression-test'

      # Fill the content textarea (English locale)
      fill_in 'block[content_en]', with: long_css

      click_button 'Save Changes'

      # Expect redirect to show page
      expect(page).to have_current_path(%r{/host/content/blocks/[^/]+$}, wait: 10)

      # Re-open edit to read back the stored value
      click_link 'Edit', match: :first

      stored = find_field('block[content_en]').value
      expect(stored.length).to be > 255
      expect(stored).to eq(long_css)
    end
  end

  describe 'edit a CssBlock' do
    let(:edit_identifier) { "edit-test-#{SecureRandom.hex(4)}" }
    let!(:css_block) do
      create(:better_together_content_css,
             identifier: edit_identifier,
             content_text: '.original { color: blue; }')
    end

    it 'updates the CSS content and reflects the change on the show page' do
      visit better_together.edit_content_block_path(
        locale: I18n.default_locale,
        id: css_block.id
      )

      fill_in 'block[content_en]', with: '.updated { color: green; }'
      click_button 'Save Changes'

      expect(page).to have_current_path(%r{/host/content/blocks/#{css_block.id}$}, wait: 10)
      expect(css_block.reload.content).to eq('.updated { color: green; }')
    end
  end

  describe 'delete a CssBlock' do
    let!(:css_block) do
      create(:better_together_content_css,
             content_text: '.to-be-deleted { display: none; }')
    end

    it 'destroys the block and redirects to the index' do
      visit better_together.content_block_path(
        locale: I18n.default_locale,
        id: css_block.id
      )

      accept_confirm do
        click_button 'Delete', match: :first
      end

      expect(page).to have_current_path(
        better_together.content_blocks_path(locale: I18n.default_locale),
        wait: 10
      )
      expect(BetterTogether::Content::Block.find_by(id: css_block.id)).to be_nil
    end
  end
end
