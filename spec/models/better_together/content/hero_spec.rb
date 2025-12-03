# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content # rubocop:todo Metrics/ModuleLength
    RSpec.describe Hero do
      describe 'Factory' do
        it 'has a valid factory' do
          hero = build(:content_hero)
          expect(hero).to be_valid
        end

        it 'supports custom title and subtitle' do
          hero = create(:content_hero, title: 'Custom Heading', subtitle: 'Custom Content')
          expect(hero.heading).to eq('Custom Heading')
          expect(hero.content.to_plain_text).to include('Custom Content')
        end
      end

      describe 'Associations' do
        it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
        it { is_expected.to have_many(:pages).through(:page_blocks) }
      end

      describe 'Translatable Attributes' do
        it { is_expected.to respond_to(:heading) }
        it { is_expected.to respond_to(:cta_text) }
        it { is_expected.to respond_to(:content) }

        it 'supports translations for heading' do
          hero = create(:content_hero)

          I18n.with_locale(:en) do
            hero.heading = 'English Heading'
            hero.save!
          end

          I18n.with_locale(:fr) do
            hero.heading = 'Titre Français'
            hero.save!
          end

          expect(hero.heading_en).to eq('English Heading')
          expect(hero.heading_fr).to eq('Titre Français')
        end
      end

      describe 'Store Attributes' do
        describe 'content_data' do
          it { is_expected.to respond_to(:cta_url) }

          it 'can set cta_url' do
            hero = create(:content_hero, cta_url: 'https://example.com')
            expect(hero.cta_url).to eq('https://example.com')
          end
        end

        describe 'css_settings' do
          it { is_expected.to respond_to(:css_classes) }
          it { is_expected.to respond_to(:container_class) }
          it { is_expected.to respond_to(:overlay_color) }
          it { is_expected.to respond_to(:overlay_opacity) }
          it { is_expected.to respond_to(:heading_color) }
          it { is_expected.to respond_to(:paragraph_color) }
          it { is_expected.to respond_to(:cta_button_style) }

          it 'has default values' do
            hero = build(:content_hero)
            expect(hero.css_classes).to eq('text-white')
            expect(hero.container_class).to eq('')
            expect(hero.overlay_color).to eq('#000')
            expect(hero.overlay_opacity).to eq(0.25)
            expect(hero.heading_color).to eq('')
            expect(hero.paragraph_color).to eq('')
            expect(hero.cta_button_style).to eq('btn-primary')
          end
        end
      end

      describe 'Validations' do
        describe 'cta_button_style' do
          it 'validates inclusion in AVAILABLE_BTN_CLASSES values' do
            hero = build(:content_hero, cta_button_style: 'invalid-class')
            expect(hero).not_to be_valid
            expect(hero.errors[:cta_button_style]).to include('is not included in the list')
          end

          it 'accepts valid button classes' do
            BetterTogether::Content::Hero::AVAILABLE_BTN_CLASSES.each_value do |btn_class|
              hero = build(:content_hero, cta_button_style: btn_class)
              expect(hero).to be_valid
            end
          end
        end
      end

      describe 'Instance Methods' do
        describe '#overlay_styles' do
          it 'returns hash with background_color and opacity' do
            hero = create(:content_hero, overlay_color: '#FF0000', overlay_opacity: 0.5)
            styles = hero.overlay_styles

            expect(styles).to be_a(Hash)
            expect(styles[:background_color]).to eq('#FF0000')
            expect(styles[:opacity]).to eq(0.5)
          end
        end

        describe '#inline_overlay_styles' do
          it 'returns CSS inline style string' do
            hero = create(:content_hero, overlay_color: '#00FF00', overlay_opacity: 0.75)
            inline_styles = hero.inline_overlay_styles

            expect(inline_styles).to be_a(String)
            expect(inline_styles).to include('background-color')
            expect(inline_styles).to include('#00FF00')
            expect(inline_styles).to include('opacity')
            expect(inline_styles).to include('0.75')
          end
        end
      end

      describe 'Constants' do
        describe 'AVAILABLE_BTN_CLASSES' do
          it 'includes primary button variants' do
            expect(BetterTogether::Content::Hero::AVAILABLE_BTN_CLASSES).to include(
              primary: 'btn-primary',
              primary_outline: 'btn-outline-primary'
            )
          end

          it 'includes all Bootstrap button variants' do
            expected_keys = %i[primary primary_outline secondary secondary_outline success success_outline
                               info info_outline warning warning_outline danger danger_outline
                               light light_outline dark dark_outline]

            expect(BetterTogether::Content::Hero::AVAILABLE_BTN_CLASSES.keys).to match_array(expected_keys)
          end
        end
      end

      describe 'Factory Traits' do
        it 'supports primary_button trait' do
          hero = create(:content_hero, :primary_button)
          expect(hero.cta_button_style).to eq('btn-primary')
        end

        it 'supports secondary_button trait' do
          hero = create(:content_hero, :secondary_button)
          expect(hero.cta_button_style).to eq('btn-secondary')
        end

        it 'supports dark_overlay trait' do
          hero = create(:content_hero, :dark_overlay)
          expect(hero.overlay_color).to eq('#000')
          expect(hero.overlay_opacity).to eq(0.5)
        end

        it 'supports light_overlay trait' do
          hero = create(:content_hero, :light_overlay)
          expect(hero.overlay_color).to eq('#fff')
          expect(hero.overlay_opacity).to eq(0.3)
        end

        it 'supports with_background_image trait' do
          hero = create(:content_hero, :with_background_image)
          expect(hero.background_image_file).to be_attached
        end
      end
    end
  end
end
