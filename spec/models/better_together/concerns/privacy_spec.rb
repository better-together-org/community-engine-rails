# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Privacy do # rubocop:todo RSpec/SpecFilePathFormat
  # Test using the actual Page model which includes Privacy
  describe 'scopes' do
    before do
      BetterTogether::Page.delete_all
      create(:better_together_page, title: 'Public Page', slug: 'public-test', privacy: 'public')
      create(:better_together_page, title: 'Community Page', slug: 'community-test', privacy: 'community')
      create(:better_together_page, title: 'Private Page', slug: 'private-test', privacy: 'private')
    end

    describe '.privacy_public' do
      it 'returns only public records' do
        results = BetterTogether::Page.privacy_public
        expect(results.count).to be >= 1
        results.each do |record|
          expect(record.privacy).to eq('public')
        end
      end
    end

    describe '.privacy_community' do
      it 'returns only community records' do
        results = BetterTogether::Page.privacy_community
        expect(results.count).to be >= 1
        results.each do |record|
          expect(record.privacy).to eq('community')
        end
      end
    end

    describe '.privacy_private' do
      it 'returns only private records' do
        results = BetterTogether::Page.privacy_private
        expect(results.count).to be >= 1
        results.each do |record|
          expect(record.privacy).to eq('private')
        end
      end
    end
  end

  describe 'privacy enum' do
    let(:page) { build(:better_together_page, privacy: 'public') }

    it 'defines all privacy levels' do
      expect(BetterTogether::Page.privacies.keys).to contain_exactly('public', 'community', 'private')
    end

    it 'allows setting privacy to public' do
      page.privacy = 'public'
      expect(page.privacy_public?).to be true
      expect(page.privacy).to eq('public')
    end

    it 'allows setting privacy to community' do
      page.privacy = 'community'
      expect(page.privacy_community?).to be true
      expect(page.privacy).to eq('community')
    end

    it 'allows setting privacy to private' do
      page.privacy = 'private'
      expect(page.privacy_private?).to be true
      expect(page.privacy).to eq('private')
    end

    it 'prefixes enum methods with privacy_' do
      expect(page).to respond_to(:privacy_public?)
      expect(page).to respond_to(:privacy_community?)
      expect(page).to respond_to(:privacy_private?)
    end
  end

  describe 'validations' do
    let(:page) { build(:better_together_page) }

    it 'requires privacy to be present' do
      page.privacy = nil
      page.valid?
      expect(page.errors[:privacy]).to include("can't be blank")
    end

    it 'validates privacy is in allowed values' do
      expect { page.privacy = 'invalid' }.to raise_error(ArgumentError)
    end

    it 'accepts all defined privacy levels' do
      %w[public community private].each do |level|
        page.privacy = level
        expect(page).to be_valid
      end
    end
  end

  describe 'translations' do
    it 'provides translated privacy level names' do
      I18n.with_locale(:en) do
        expect(I18n.t('attributes.privacy_list.public')).to eq('Public')
        expect(I18n.t('attributes.privacy_list.community')).to eq('Community')
        expect(I18n.t('attributes.privacy_list.private')).not_to be_nil
      end
    end

    it 'has translations for all supported locales' do
      I18n.available_locales.each do |locale|
        I18n.with_locale(locale) do
          expect(I18n.t('attributes.privacy_list.public')).not_to match(/translation missing/)
          expect(I18n.t('attributes.privacy_list.community')).not_to match(/translation missing/)
        end
      end
    end
  end

  describe '.extra_permitted_attributes' do
    it 'includes privacy in permitted attributes' do
      expect(BetterTogether::Page.extra_permitted_attributes).to include(:privacy)
    end
  end

  describe '.included_in_models' do
    it 'returns models that include Privacy concern' do
      models = described_class.included_in_models
      expect(models).to include(BetterTogether::Page)
      expect(models.all? { |m| m.included_modules.include?(described_class) }).to be true
    end
  end

  describe 'privacy level semantics' do
    let(:page) { build(:better_together_page) }

    context 'when privacy is public' do
      it 'indicates content visible to everyone' do
        page.privacy = 'public'
        expect(page.privacy_public?).to be true
        expect(page.privacy_community?).to be false
        expect(page.privacy_private?).to be false
      end
    end

    context 'when privacy is community' do
      it 'indicates content visible to authenticated community members' do
        page.privacy = 'community'
        expect(page.privacy_public?).to be false
        expect(page.privacy_community?).to be true
        expect(page.privacy_private?).to be false
      end
    end

    context 'when privacy is private' do
      it 'indicates content visible only to owner' do
        page.privacy = 'private'
        expect(page.privacy_public?).to be false
        expect(page.privacy_community?).to be false
        expect(page.privacy_private?).to be true
      end
    end
  end

  describe 'database storage' do
    it 'stores privacy as string value' do
      page = create(:better_together_page, privacy: 'community')

      # Reload from database
      reloaded = BetterTogether::Page.find(page.id)
      expect(reloaded.privacy).to eq('community')
      expect(reloaded.read_attribute(:privacy)).to eq('community')
    end

    it 'stores all privacy levels as recognizable strings' do
      %w[public community private].each do |level|
        record = create(:better_together_page,
                        slug: "test-#{level}-#{SecureRandom.hex(4)}",
                        privacy: level)

        expect(record.read_attribute(:privacy)).to eq(level)
        expect(record.reload.read_attribute(:privacy)).to eq(level)
      end
    end
  end
end
