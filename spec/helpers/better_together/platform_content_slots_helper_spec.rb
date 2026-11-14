# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformContentSlotsHelper do
  let(:platform) { create(:better_together_platform) }
  let(:other_platform) { create(:better_together_platform) }

  before do
    allow(BetterTogether::PublicVisibilityGate).to receive(:allow!).and_return(true)
    current = platform
    helper.define_singleton_method(:host_platform) { current }
  end

  def save_slot(target, slot, attrs)
    target.update!(content_slot_blocks_attributes: { slot => attrs })
  end

  describe '#render_platform_content_slot' do
    it 'renders nothing when the slot is empty' do
      expect(helper.render_platform_content_slot(:header_above)).to be_blank
    end

    it 'renders a rich text block in a stable wrapper' do
      save_slot(platform, :header_above, type: 'BetterTogether::Content::RichText', content_en: '<div>Next foray</div>')
      html = Nokogiri::HTML.fragment(helper.render_platform_content_slot(:header_above))

      expect(html.at_css('#platform-slot-header-above[data-platform-content-slot="header_above"]').text).to include('Next foray')
    end

    it 'sanitizes an Html block' do
      save_slot(platform, :footer_above, type: 'BetterTogether::Content::Html',
                                         content_en: '<p>Safe</p><script>alert(1)</script>')
      html = helper.render_platform_content_slot(:footer_above)

      expect(html).to include('Safe')
      expect(html).not_to include('<script')
    end

    it 'renders a Markdown block' do
      save_slot(platform, :not_found_message, type: 'BetterTogether::Content::Markdown', markdown_source: '**Lost?**')

      expect(helper.render_platform_content_slot(:not_found_message)).to include('<strong>Lost?</strong>')
    end

    it 'never shows another platform block' do
      save_slot(other_platform, :header_above, type: 'BetterTogether::Content::RichText', content_en: '<div>Theirs</div>')

      expect(helper.render_platform_content_slot(:header_above)).to be_blank
    end

    it 'ignores a reserved identifier held by a block of a disallowed type' do
      create(:content_alert_block, platform:, identifier: 'slot-header-above', privacy: platform.privacy)

      expect(helper.render_platform_content_slot(:header_above)).to be_blank
    end

    it 'skips a block that is not visible' do
      save_slot(platform, :header_above, type: 'BetterTogether::Content::RichText', content_en: '<div>Hidden</div>')
      platform.content_slot_block(:header_above).update_columns(visible: false)
      platform.reload

      expect(helper.render_platform_content_slot(:header_above)).to be_blank
    end

    it 'fails open when rendering raises' do
      save_slot(platform, :header_above, type: 'BetterTogether::Content::RichText', content_en: '<div>Boom</div>')
      allow(helper).to receive(:content_slot_body).and_raise(StandardError, 'boom')

      expect(helper.render_platform_content_slot(:header_above)).to be_nil
    end

    it 'is nil safe for an unsaved platform' do
      expect(helper.render_platform_content_slot(:header_above, platform: BetterTogether::Platform.new)).to be_nil
    end

    it 'includes the platform, locale and block version in the fragment cache key' do
      save_slot(platform, :header_above, type: 'BetterTogether::Content::RichText', content_en: '<div>Keyed</div>')
      block = platform.content_slot_block(:header_above)
      allow(helper).to receive(:cache).and_call_original

      helper.render_platform_content_slot(:header_above)

      expect(helper).to have_received(:cache)
        .with(['platform-content-slot', platform.id, 'header_above', I18n.locale, block.cache_key_with_version])
    end
  end

  describe '#platform_not_found_headline' do
    it 'returns nil with no headlines block' do
      expect(helper.platform_not_found_headline).to be_nil
    end

    it 'picks one of the lines, stripping markup and blanks' do
      save_slot(platform, :not_found_headlines, type: 'BetterTogether::Content::Html',
                                                content_en: "Lost in the woods\n\n<b>Nothing here</b>\n")

      picks = Array.new(20) { helper.platform_not_found_headline }.uniq
      expect(picks - ['Lost in the woods', 'Nothing here']).to be_empty
    end

    it 'caps the line length' do
      save_slot(platform, :not_found_headlines, type: 'BetterTogether::Content::Html', content_en: 'a' * 300)

      expect(helper.platform_not_found_headline.length).to be <= described_class::MAX_HEADLINE_LENGTH
    end
  end
end
