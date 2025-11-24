# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content # rubocop:todo Metrics/ModuleLength
    RSpec.describe Image do
      describe 'Factory' do
        it 'has a valid factory' do
          image_block = build(:better_together_content_image)
          expect(image_block).to be_valid
        end

        it 'creates with attached media' do
          image_block = create(:better_together_content_image)
          expect(image_block.media).to be_attached
        end

        it 'creates with caption and attribution' do
          image_block = create(:better_together_content_image,
                               caption: 'Test caption',
                               attribution: 'Test photographer')
          expect(image_block.caption).to eq('Test caption')
          expect(image_block.attribution).to eq('Test photographer')
        end
      end

      describe 'Associations' do
        it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
        it { is_expected.to have_many(:pages).through(:page_blocks) }
      end

      describe 'Active Storage Attachment' do
        it 'has one attached media file' do
          image_block = create(:better_together_content_image)
          expect(image_block.media).to be_attached
          expect(image_block.media.filename.to_s).to eq('test-image.png')
        end

        it 'delegates url to media' do
          # Set ActiveStorage url_options for test environment
          ActiveStorage::Current.url_options = { host: 'localhost', port: 3000, protocol: 'http' }

          image_block = create(:better_together_content_image)
          expect(image_block).to respond_to(:url)
          expect(image_block.url).to be_present
          expect(image_block.url).to include('test-image.png')
        end
      end

      describe 'Validations' do
        describe 'media presence' do
          it 'requires media attachment' do
            image_block = build(:better_together_content_image)
            image_block.media.purge
            expect(image_block).not_to be_valid
            expect(image_block.errors[:media]).to include("can't be blank")
          end
        end

        describe 'attribution_url format' do
          it 'accepts valid HTTP URLs' do
            image_block = build(:better_together_content_image, attribution_url: 'http://example.com')
            expect(image_block).to be_valid
          end

          it 'accepts valid HTTPS URLs' do
            image_block = build(:better_together_content_image, attribution_url: 'https://example.com')
            expect(image_block).to be_valid
          end

          it 'accepts URLs with paths' do
            image_block = build(:better_together_content_image,
                                attribution_url: 'https://example.com/path/to/image')
            expect(image_block).to be_valid
          end

          it 'allows blank attribution_url' do
            image_block = build(:better_together_content_image, attribution_url: '')
            expect(image_block).to be_valid
          end

          it 'rejects invalid URLs' do
            image_block = build(:better_together_content_image, attribution_url: 'not a url')
            expect(image_block).not_to be_valid
            expect(image_block.errors[:attribution_url]).to be_present
          end

          it 'rejects URLs without protocol' do
            image_block = build(:better_together_content_image, attribution_url: 'example.com')
            expect(image_block).not_to be_valid
          end
        end

        describe 'media content type' do
          it 'accepts JPEG images' do
            image_block = build(:better_together_content_image, :with_jpg)
            expect(image_block).to be_valid
          end

          it 'accepts GIF images' do
            image_block = build(:better_together_content_image, :with_gif)
            expect(image_block).to be_valid
          end

          it 'accepts WebP images' do
            image_block = build(:better_together_content_image, :with_webp)
            expect(image_block).to be_valid
          end
        end
      end

      describe 'Translatable Attributes' do
        it { is_expected.to respond_to(:attribution) }
        it { is_expected.to respond_to(:alt_text) }
        it { is_expected.to respond_to(:caption) }

        it 'supports translations for attribution' do
          image_block = create(:better_together_content_image)

          I18n.with_locale(:en) do
            image_block.attribution = 'English Photographer'
            image_block.save!
          end

          I18n.with_locale(:fr) do
            image_block.attribution = 'Photographe Français'
            image_block.save!
          end

          expect(image_block.attribution_en).to eq('English Photographer')
          expect(image_block.attribution_fr).to eq('Photographe Français')
        end

        it 'supports translations for alt_text' do
          image_block = create(:better_together_content_image)

          I18n.with_locale(:en) do
            image_block.alt_text = 'English description'
            image_block.save!
          end

          I18n.with_locale(:es) do
            image_block.alt_text = 'Descripción en español'
            image_block.save!
          end

          expect(image_block.alt_text_en).to eq('English description')
          expect(image_block.alt_text_es).to eq('Descripción en español')
        end

        it 'supports translations for caption' do
          image_block = create(:better_together_content_image)

          I18n.with_locale(:en) do
            image_block.caption = 'English caption'
            image_block.save!
          end

          I18n.with_locale(:fr) do
            image_block.caption = 'Légende française'
            image_block.save!
          end

          expect(image_block.caption_en).to eq('English caption')
          expect(image_block.caption_fr).to eq('Légende française')
        end
      end

      describe 'Store Attributes' do
        describe 'media_settings' do
          it { is_expected.to respond_to(:media_settings) }
          it { is_expected.to respond_to(:attribution_url) }

          it 'can store attribution_url' do
            image_block = create(:better_together_content_image)
            image_block.update(attribution_url: 'https://example.com/photo')
            expect(image_block.attribution_url).to eq('https://example.com/photo')
          end

          it 'has default empty string for attribution_url' do
            image_block = create(:better_together_content_image, attribution_url: nil)
            image_block.reload
            # Store attributes default to empty string per model definition
            expect(image_block.attribution_url).to eq('').or be_nil
          end
        end
      end

      describe 'Class Methods' do
        describe '.content_addable?' do
          it 'returns true' do
            expect(described_class.content_addable?).to be true
          end
        end

        describe '.extra_permitted_attributes' do
          it 'includes media attribute' do
            expect(described_class.extra_permitted_attributes).to include(:media)
          end
        end
      end

      describe 'Constants' do
        describe 'CONTENT_TYPES' do
          it 'includes common image formats' do
            expect(Image::CONTENT_TYPES).to include('image/jpeg')
            expect(Image::CONTENT_TYPES).to include('image/png')
            expect(Image::CONTENT_TYPES).to include('image/gif')
            expect(Image::CONTENT_TYPES).to include('image/webp')
            expect(Image::CONTENT_TYPES).to include('image/svg+xml')
          end
        end
      end

      describe 'Inheritance' do
        it 'inherits from Block' do
          expect(described_class.superclass).to eq(Block)
        end
      end
    end
  end
end
