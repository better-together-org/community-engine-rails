# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_content_slots_spec.rb
#
# Documents the content slot fields in the Appearance tab and a 404 page using slot content.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for platform content slots', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    allow(BetterTogether::PublicVisibilityGate).to receive(:allow!).and_return(true)
    host_platform.content_slot_blocks_attributes = BetterTogether::PlatformContentSlots::SLOTS.keys.index_with { { remove: '1' } }
    host_platform.save!
    Current.platform = nil
  end

  def seed_slots
    allow(BetterTogether::PublicVisibilityGate).to receive(:allow!).and_return(true)
    host_platform.update!(content_slot_blocks_attributes: {
                            header_above: { type: 'BetterTogether::Content::RichText',
                                            content_en: '<div class="text-center">Next foray: join us in September</div>' },
                            footer_above: { type: 'BetterTogether::Content::RichText',
                                            content_en: '<div class="text-center">Made with support from our funders</div>' },
                            not_found_headlines: { type: 'BetterTogether::Content::Html',
                                                   content_en: 'Nothing here but mushrooms' },
                            not_found_message: { type: 'BetterTogether::Content::RichText',
                                                 content_en: '<div>Try the forays page instead.</div>' }
                          })
  end

  [false, true].each do |annotated|
    it "captures the slot fields#{' annotated' if annotated}" do
      name = "platform_content_slots_fields#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#platform-content-slot-field-footer-above', title: 'Content slots',
                      bullets: ['Same editor as every other block', 'Leave empty for the standard layout'],
                      position: 'below' }]
                 else
                   []
                 end
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        name, device: :both, callouts:,
              metadata: { locale:, role: 'platform_manager', feature_set: 'platform_content_slots', flow: name,
                          source_spec: self.class.metadata[:file_path] }
      ) do
        capybara_login_as_platform_manager
        visit edit_platform_path(host_platform, locale:)
        find('#platform-appearance-tab').click
        expect(page).to have_css('#platform-content-slots', wait: 10)
        scroll_to(find('#platform-content-slot-field-footer-above'), align: :center)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end

    it "captures a 404 page with slot content#{' annotated' if annotated}" do
      seed_slots
      name = "platform_content_slots_404#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#not-found-headline', title: 'Custom 404',
                      bullets: ['Headline picked from the 404 headlines slot'], position: 'below' }]
                 else
                   []
                 end
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        name, device: :both, callouts:,
              metadata: { locale:, role: 'visitor', feature_set: 'platform_content_slots', flow: name,
                          source_spec: self.class.metadata[:file_path] }
      ) do
        visit "/#{locale}/no-such-page-for-docs"
        expect(page).to have_css('#not-found-headline', text: 'Nothing here but mushrooms', wait: 10)
        scroll_to(find('#not-found-headline'), align: :center)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end
  end
end
