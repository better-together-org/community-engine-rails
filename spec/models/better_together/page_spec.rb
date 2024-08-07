# frozen_string_literal: true

# spec/models/better_together/page_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe Page, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:page) { build(:better_together_page) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(page).to be_valid
      end
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_presence_of(:privacy) }
      it { is_expected.to validate_presence_of(:language) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:title) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:content) }
      it { is_expected.to respond_to(:meta_description) }
      it { is_expected.to respond_to(:keywords) }
      it { is_expected.to respond_to(:published) }
      it { is_expected.to respond_to(:published_at) }
      it { is_expected.to respond_to(:privacy) }
      it { is_expected.to respond_to(:layout) }
      it { is_expected.to respond_to(:template) }
      it { is_expected.to respond_to(:language) }
      it { is_expected.to respond_to(:protected) }
    end

    describe 'Scopes' do
      describe '.published' do
        it 'returns only published pages' do
          published_page_count = Page.published.count
          create(:better_together_page, published: false)
          expect(Page.published.count).to eq(published_page_count)
        end
      end

      describe '.by_publication_date' do
        it 'orders pages by published date descending' do
          # Create pages and test the order
        end
      end

      describe '.privacy_public' do
        it 'returns only public pages' do
          public_pages_count = Page.privacy_public.count
          create(:better_together_page, privacy: 'closed')
          expect(Page.privacy_public.count).to eq(public_pages_count)
        end
      end
    end

    describe 'Methods' do
      describe '#published?' do
        it 'returns true if the page is published' do
          page.published = true
          expect(page.published?).to be true
        end

        it 'returns false if the page is not published' do
          page.published = false
          expect(page.published?).to be false
        end
      end

      describe '#to_s' do
        it 'returns the title' do
          expect(page.to_s).to eq(page.title)
        end
      end

      describe '#url' do
        it 'returns the full URL of the page' do
          expect(page.url).to eq("#{::BetterTogether.base_url_with_locale}/#{page.slug}")
        end
      end
    end
  end
end
