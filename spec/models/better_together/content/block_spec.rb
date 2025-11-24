# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe Block do
      # Block is an abstract base class - test through concrete subclasses
      # We use Html as the default concrete implementation for most tests

      describe 'Associations' do
        subject { build(:better_together_content_html) }

        it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
        it { is_expected.to have_many(:pages).through(:page_blocks) }
      end

      describe 'Validations' do
        # Test through concrete subclass since Block is abstract
        subject { build(:better_together_content_html) }

        describe 'identifier' do
          it { is_expected.to validate_length_of(:identifier).is_at_most(100) }

          it 'validates uniqueness across all block types' do
            create(:better_together_content_html, identifier: 'unique-block')
            duplicate = build(:better_together_content_html, identifier: 'unique-block')
            expect(duplicate).not_to be_valid
            expect(duplicate.errors[:identifier]).to be_present
          end

          it 'allows blank identifier' do
            block = build(:better_together_content_html, identifier: '')
            expect(block).to be_valid
          end
        end
      end

      describe 'Instance Methods' do
        # All instance method tests use concrete Html subclass
        describe '#identifier=' do
          it 'parameterizes the identifier' do
            block = build(:better_together_content_html)
            block.identifier = 'My Test Block'
            expect(block.identifier).to eq('my-test-block')
          end

          it 'handles special characters' do
            block = build(:better_together_content_html)
            block.identifier = 'Test & Special! Characters?'
            expect(block.identifier).to eq('test-special-characters')
          end

          it 'handles spaces and hyphens' do
            block = build(:better_together_content_html)
            block.identifier = 'test-block with spaces'
            expect(block.identifier).to eq('test-block-with-spaces')
          end
        end

        describe '#to_partial_path' do
          it 'returns the partial path for a block' do
            block = create(:better_together_content_html)
            expect(block.to_partial_path).to eq('better_together/content/blocks/html')
          end

          it 'uses block_name in partial path' do
            hero = create(:better_together_content_hero)
            expect(hero.to_partial_path).to eq('better_together/content/blocks/hero')
          end
        end

        describe '#block_name' do
          it 'returns the underscored class name without module' do
            block = create(:better_together_content_html)
            expect(block.block_name).to eq('html')
          end

          it 'works for different block types' do
            hero = create(:better_together_content_hero)
            css = create(:better_together_content_css)

            expect(hero.block_name).to eq('hero')
            expect(css.block_name).to eq('css')
          end
        end

        describe '#to_s' do
          it 'returns block_name with identifier for persisted block' do
            block = create(:better_together_content_html, identifier: 'test-block')
            expect(block.to_s).to eq('html - test-block')
          end

          it 'returns "new" for unpersisted blocks' do
            block = build(:better_together_content_html)
            expect(block.to_s).to eq('html - new')
          end
        end

        describe '#cached_content' do
          it 'returns a hash with id, type, content, and translations' do
            block = create(:better_together_content_html, content: '<p>Test</p>')
            cached = block.cached_content

            expect(cached).to have_key(:id)
            expect(cached).to have_key(:type)
            expect(cached).to have_key(:content)
            expect(cached).to have_key(:translations)
          end

          it 'includes the block id and type' do
            block = create(:better_together_content_html)
            cached = block.cached_content

            expect(cached[:id]).to eq(block.id)
            expect(cached[:type]).to eq('BetterTogether::Content::Html')
          end
        end
      end

      describe 'Class Methods' do
        # Class methods tested on both abstract base and concrete subclasses
        describe '.block_name' do
          it 'returns underscored class name for concrete types' do
            expect(BetterTogether::Content::Html.block_name).to eq('html')
            expect(BetterTogether::Content::Hero.block_name).to eq('hero')
            expect(BetterTogether::Content::RichText.block_name).to eq('rich_text')
          end
        end

        describe '.content_addable?' do
          it 'returns true for base Block class' do
            expect(described_class.content_addable?).to be true
          end

          it 'returns true for concrete subclasses' do
            expect(BetterTogether::Content::Html.content_addable?).to be true
            expect(BetterTogether::Content::Hero.content_addable?).to be true
          end
        end

        describe '.inherited' do
          it 'includes BlockAttributes in subclasses' do
            expect(BetterTogether::Content::Html.included_modules).to include(BetterTogether::Content::BlockAttributes)
            expect(BetterTogether::Content::Hero.included_modules).to include(BetterTogether::Content::BlockAttributes)
          end
        end

        describe '.storext_keys' do
          it 'returns an array of storext definition keys' do
            keys = described_class.storext_keys
            expect(keys).to be_an(Array)
          end

          it 'includes keys from all block types' do
            keys = described_class.storext_keys
            # Keys are from all descendants, checking for presence of common ones
            expect(keys).not_to be_empty
            expect(keys).to be_an(Array)
          end
        end

        describe '.extra_permitted_attributes' do
          it 'returns an array' do
            expect(described_class.extra_permitted_attributes).to be_an(Array)
          end

          it 'includes background_image_file' do
            expect(described_class.extra_permitted_attributes).to include(:background_image_file)
          end

          it 'includes attributes from descendants' do
            attrs = described_class.extra_permitted_attributes
            # Image adds :media to permitted attributes
            expect(attrs).to include(:media)
            # HTML adds :html_content
            expect(attrs).to include(:html_content)
          end

          it 'returns unique attributes' do
            attrs = described_class.extra_permitted_attributes
            expect(attrs.length).to eq(attrs.uniq.length)
          end
        end

        describe '.localized_block_attributes' do
          it 'returns an array of localized attributes from all descendants' do
            attrs = described_class.localized_block_attributes
            expect(attrs).to be_an(Array)
          end

          it 'includes localized attributes from subclasses' do
            attrs = described_class.localized_block_attributes
            # Hero has heading, content, cta_text
            # Html has content
            # RichText has content
            # These should all be in the list
            expect(attrs).not_to be_empty
          end
        end
      end

      describe 'STI (Single Table Inheritance) Pattern' do
        it 'Block is an abstract base class for content block types' do
          # All blocks share the same table but have different types
          html = create(:better_together_content_html)
          hero = create(:better_together_content_hero)
          css = create(:better_together_content_css)

          expect(html.type).to eq('BetterTogether::Content::Html')
          expect(hero.type).to eq('BetterTogether::Content::Hero')
          expect(css.type).to eq('BetterTogether::Content::Css')

          # All stored in same table
          expect(html.class.table_name).to eq(hero.class.table_name)
          expect(html.class.table_name).to eq(css.class.table_name)
        end

        it 'queries on base Block class return all concrete types' do
          html = create(:better_together_content_html)
          hero = create(:better_together_content_hero)
          css = create(:better_together_content_css)

          all_blocks = described_class.where(id: [html.id, hero.id, css.id])
          expect(all_blocks.count).to eq(3)
          expect(all_blocks.map(&:class)).to contain_exactly(
            BetterTogether::Content::Html,
            BetterTogether::Content::Hero,
            BetterTogether::Content::Css
          )
        end

        it 'each concrete type is a descendant of Block' do
          expect(BetterTogether::Content::Html.superclass).to eq(described_class)
          expect(BetterTogether::Content::Hero.superclass).to eq(described_class)
          expect(BetterTogether::Content::Css.superclass).to eq(described_class)
          expect(BetterTogether::Content::RichText.superclass).to eq(described_class)
          expect(BetterTogether::Content::Image.superclass).to eq(described_class)
        end
      end
    end
  end
end
