# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe PlatformBlock do
      describe 'Associations' do
        it { is_expected.to belong_to(:platform).class_name('BetterTogether::Platform').touch(true) }
        it { is_expected.to belong_to(:block).class_name('BetterTogether::Content::Block').autosave(true) }
      end

      describe 'Nested Attributes' do
        it 'accepts nested attributes for block' do
          platform = create(:better_together_platform)

          platform_block = described_class.new(
            platform: platform,
            block_attributes: {
              type: 'BetterTogether::Content::Html',
              identifier: 'test-block',
              privacy: 'public'
            }
          )

          # Should accept the nested attributes without error
          expect { platform_block.save }.not_to raise_error
        end
      end

      describe 'Integration' do
        it 'creates with platform and block' do
          platform = create(:better_together_platform)
          block = create(:better_together_content_html, content: '<p>Test content</p>')

          platform_block = described_class.create!(platform: platform, block: block)

          expect(platform_block).to be_persisted
          expect(platform_block.platform).to eq(platform)
          expect(platform_block.block).to eq(block)
        end

        it 'touches platform when updated' do
          platform = create(:better_together_platform)
          block = create(:better_together_content_html)
          platform_block = described_class.create!(platform: platform, block: block)

          original_updated_at = platform.reload.updated_at
          sleep 0.01 # Ensure time difference
          platform_block.touch

          expect(platform.reload.updated_at).to be > original_updated_at
        end
      end
    end
  end
end
