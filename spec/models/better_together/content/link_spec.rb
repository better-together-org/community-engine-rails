# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe Link do
      describe 'Factory' do
        it 'has a valid factory' do
          link = build(:content_link)
          expect(link).to be_valid
        end

        it 'creates with default attributes' do
          link = create(:content_link)
          expect(link.link_type).to eq('website')
          expect(link.valid_link).to be false
          expect(link.scheme).to eq('https')
          expect(link.host).to be_present
        end

        it 'creates with custom URL' do
          link = create(:content_link, url: 'https://custom.example.com/path')
          expect(link.url).to eq('https://custom.example.com/path')
          expect(link.host).to eq('custom.example.com')
        end
      end

      describe 'Associations' do
        it { is_expected.to have_many(:rich_text_links).class_name('BetterTogether::Metrics::RichTextLink') }
        it { is_expected.to have_many(:rich_texts).through(:rich_text_links) }

        # NOTE: rich_text_records association is polymorphic and requires source_type
        # It's tested indirectly through the has_many :rich_text_links association
      end

      describe 'Initialization defaults' do
        it 'sets link_type to "website" when blank' do
          link = described_class.new
          expect(link.link_type).to eq('website')
        end

        it 'does not override provided link_type' do
          link = described_class.new(link_type: 'external')
          expect(link.link_type).to eq('external')
        end

        it 'sets valid_link to false when nil' do
          link = described_class.new
          expect(link.valid_link).to be false
        end

        it 'does not override provided valid_link value' do
          link = described_class.new(valid_link: true)
          expect(link.valid_link).to be true
        end
      end

      describe 'Attributes' do
        it 'stores URL' do
          link = create(:content_link, url: 'https://example.com/page')
          expect(link.url).to eq('https://example.com/page')
        end

        it 'stores scheme' do
          link = create(:content_link, scheme: 'http')
          expect(link.scheme).to eq('http')
        end

        it 'stores host' do
          link = create(:content_link, host: 'example.org')
          expect(link.host).to eq('example.org')
        end

        it 'tracks external status' do
          external_link = create(:content_link, external: true)
          internal_link = create(:content_link, external: false)

          expect(external_link.external).to be true
          expect(internal_link.external).to be false
        end

        it 'tracks link validity' do
          valid_link = create(:content_link, valid_link: true)
          invalid_link = create(:content_link, valid_link: false)

          expect(valid_link.valid_link).to be true
          expect(invalid_link.valid_link).to be false
        end
      end

      describe 'Link metadata tracking' do
        it 'can distinguish between internal and external links' do
          internal = create(:content_link, external: false, url: 'https://mysite.com/page')
          external = create(:content_link, external: true, url: 'https://othersite.com/page')

          expect(internal.external).to be false
          expect(external.external).to be true
        end

        it 'supports different link types' do
          website = create(:content_link, link_type: 'website')
          email = create(:content_link, link_type: 'email', url: 'mailto:test@example.com')
          tel = create(:content_link, link_type: 'tel', url: 'tel:+1234567890')

          expect(website.link_type).to eq('website')
          expect(email.link_type).to eq('email')
          expect(tel.link_type).to eq('tel')
        end
      end
    end
  end
end
