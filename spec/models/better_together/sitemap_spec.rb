# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Sitemap do
    describe 'associations' do
      it { is_expected.to belong_to(:platform) }
      it { is_expected.to have_one_attached(:file) }
    end

    describe 'validations' do
      subject { build(:better_together_sitemap) }

      it { is_expected.to validate_presence_of(:locale) }

      it 'validates locale is in available locales' do
        sitemap = build(:better_together_sitemap, locale: 'invalid')
        expect(sitemap).not_to be_valid
        expect(sitemap.errors[:locale]).to include('is not included in the list')
      end

      it 'validates uniqueness of locale scoped to platform' do
        platform = create(:better_together_platform)
        create(:better_together_sitemap, platform: platform, locale: 'en')

        expect do
          create(:better_together_sitemap, platform: platform, locale: 'en')
        end.to raise_error(ActiveRecord::RecordInvalid, /Locale has already been taken/)
      end

      it 'allows same locale for different platforms' do
        platform1 = create(:better_together_platform)
        platform2 = create(:better_together_platform, host: false)

        sitemap1 = create(:better_together_sitemap, platform: platform1, locale: 'en')
        sitemap2 = build(:better_together_sitemap, platform: platform2, locale: 'en')

        expect(sitemap1).to be_valid
        expect(sitemap2).to be_valid
      end

      it 'allows index locale' do
        sitemap = build(:better_together_sitemap, :with_index)
        expect(sitemap).to be_valid
        expect(sitemap.locale).to eq('index')
      end
    end

    describe '.current' do
      let(:platform) { create(:better_together_platform) }

      it 'returns existing sitemap for platform and locale' do
        sitemap = create(:better_together_sitemap, platform: platform, locale: 'en')
        expect(described_class.current(platform, 'en')).to eq(sitemap)
      end

      it 'creates new sitemap if none exists' do
        expect do
          described_class.current(platform, 'es')
        end.to change(described_class, :count).by(1)
      end

      it 'returns sitemap for specified locale' do
        create(:better_together_sitemap, platform: platform, locale: 'en')
        es_sitemap = create(:better_together_sitemap, platform: platform, locale: 'es')

        expect(described_class.current(platform, 'es')).to eq(es_sitemap)
      end

      it 'defaults to I18n.default_locale when locale not specified' do
        I18n.with_locale(:en) do
          sitemap = create(:better_together_sitemap, platform: platform, locale: 'en')
          expect(described_class.current(platform)).to eq(sitemap)
        end
      end
    end

    describe '.current_index' do
      let(:platform) { create(:better_together_platform) }

      it 'returns existing sitemap index for platform' do
        sitemap_index = create(:better_together_sitemap, :with_index, platform: platform)
        expect(described_class.current_index(platform)).to eq(sitemap_index)
      end

      it 'creates new sitemap index if none exists' do
        expect do
          described_class.current_index(platform)
        end.to change(described_class, :count).by(1)

        expect(described_class.current_index(platform).locale).to eq('index')
      end

      it 'does not interfere with locale-specific sitemaps' do
        create(:better_together_sitemap, platform: platform, locale: 'en')
        create(:better_together_sitemap, platform: platform, locale: 'es')

        sitemap_index = described_class.current_index(platform)
        expect(sitemap_index.locale).to eq('index')
        expect(described_class.where(platform: platform).count).to eq(3)
      end
    end

    describe 'factory' do
      it 'has a valid default factory' do
        sitemap = build(:better_together_sitemap)
        expect(sitemap).to be_valid
      end

      it 'creates sitemap with attached file' do
        sitemap = create(:better_together_sitemap)
        expect(sitemap.file).to be_attached
      end

      it 'supports locale traits' do
        expect(build(:better_together_sitemap, :english).locale).to eq('en')
        expect(build(:better_together_sitemap, :spanish).locale).to eq('es')
        expect(build(:better_together_sitemap, :french).locale).to eq('fr')
        expect(build(:better_together_sitemap, :ukrainian).locale).to eq('uk')
      end

      it 'supports index trait' do
        sitemap = build(:better_together_sitemap, :with_index)
        expect(sitemap.locale).to eq('index')
        expect(sitemap.file).to be_attached
      end
    end
  end
end
