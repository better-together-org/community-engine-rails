# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformContentSlots do
  let(:platform) { create(:better_together_platform) }
  let(:other_platform) { create(:better_together_platform) }
  let(:rich_text) { 'BetterTogether::Content::RichText' }

  before do
    # Public blocks need a person who accepted the publishing agreement.
    allow(BetterTogether::PublicVisibilityGate).to receive(:allow!).and_return(true)
  end

  def save_slot(target, slot, attrs)
    target.update!(content_slot_blocks_attributes: { slot => attrs })
    target.reload
  end

  describe '#content_slot_block' do
    it 'returns nil for an unknown slot and when nothing is saved' do
      expect([platform.content_slot_block(:header_above), platform.content_slot_block(:bogus)]).to all(be_nil)
    end

    it 'finds a saved block by its reserved identifier and follows the platform privacy and is protected' do
      save_slot(platform, :header_above, type: rich_text, content_en: '<div>Hello</div>')
      block = platform.content_slot_block(:header_above)

      expect(block).to have_attributes(identifier: 'slot-header-above', privacy: platform.privacy, protected: true,
                                       platform_id: platform.id)
    end

    it 'links the block to the platform through platform_blocks' do
      save_slot(platform, :footer_above, type: rich_text, content_en: '<div>Hi</div>')

      expect(platform.blocks.pluck(:identifier)).to eq(['slot-footer-above'])
    end
  end

  describe 'platform scoping' do
    it 'allows the same slot on two platforms with no leakage in either direction' do # rubocop:disable RSpec/MultipleExpectations
      save_slot(platform, :header_above, type: rich_text, content_en: '<div>Platform one</div>')
      save_slot(other_platform, :header_above, type: rich_text, content_en: '<div>Platform two</div>')

      expect(platform.content_slot_block(:header_above).content.to_plain_text).to eq('Platform one')
      expect(other_platform.content_slot_block(:header_above).content.to_plain_text).to eq('Platform two')
      expect(platform.content_slot_block(:header_above).id).not_to eq(other_platform.content_slot_block(:header_above).id)
    end

    it 'does not see a slot block that only another platform has' do
      save_slot(platform, :footer_above, type: rich_text, content_en: '<div>Only mine</div>')

      expect(other_platform.reload.content_slot_block(:footer_above)).to be_nil
    end

    it 'updates only its own platform block when both platforms use the slot' do
      save_slot(platform, :header_above, type: rich_text, content_en: '<div>A</div>')
      save_slot(other_platform, :header_above, type: rich_text, content_en: '<div>B</div>')
      save_slot(platform, :header_above, content_en: '<div>A2</div>')

      expect(other_platform.reload.content_slot_block(:header_above).content.to_plain_text).to eq('B')
    end
  end

  describe 'validation' do
    it 'rejects a content type the slot does not allow' do
      platform.content_slot_blocks_attributes = { header_above: { type: 'BetterTogether::Content::Hero', content_en: 'x' } }

      expect(platform).not_to be_valid
      expect(platform.errors[:content_slot_blocks]).to be_present
    end

    it 'only allows the Html type for the 404 headlines slot' do
      platform.content_slot_blocks_attributes = { not_found_headlines: { type: rich_text, content_en: 'x' } }

      expect(platform).not_to be_valid
    end

    it 'rejects content over the per-language limit' do
      too_long = 'a' * (described_class::MAX_CONTENT_LENGTH + 1)
      platform.content_slot_blocks_attributes = { header_above: { type: rich_text, content_en: too_long } }

      expect(platform).not_to be_valid
    end

    it 'does not create a block for an empty submission' do
      expect { save_slot(platform, :header_above, type: rich_text, content_en: '') }
        .not_to(change { BetterTogether::Content::Block.where(platform_id: platform.id).count })
    end

    it 'ignores a client supplied identifier or platform' do
      save_slot(platform, :header_above, type: rich_text, content_en: '<div>x</div>', identifier: 'evil',
                                         platform_id: other_platform.id)

      expect(platform.content_slot_block(:header_above)).to have_attributes(identifier: 'slot-header-above',
                                                                            platform_id: platform.id)
    end
  end

  describe 'removal' do
    it 'removes a protected slot block and its join row' do
      save_slot(platform, :footer_above, type: rich_text, content_en: '<div>Bye</div>')
      save_slot(platform, :footer_above, remove: '1')

      expect([platform.content_slot_block(:footer_above), platform.platform_blocks.count]).to eq([nil, 0])
    end
  end

  describe 'localized content' do
    it 'keeps a separate value per language and falls back to the default language' do
      save_slot(platform, :header_above, type: rich_text, content_en: '<div>Hello</div>', content_fr: '<div>Bonjour</div>')
      block = platform.content_slot_block(:header_above)

      texts = %i[en fr es].map { |loc| Mobility.with_locale(loc) { block.content.to_plain_text } }
      expect(texts).to eq(%w[Hello Bonjour Hello])
    end
  end
end
