# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe WebsiteLink do
    describe 'factory' do
      it 'creates a valid website link' do
        link = build(:website_link)
        expect(link).to be_valid
      end

      it 'creates valid links with different labels' do
        %i[blog portfolio company_website community_page documentation].each do |label_trait|
          link = build(:website_link, label_trait)
          expect(link).to be_valid
        end
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:contact_detail).class_name('BetterTogether::ContactDetail').touch(true) }
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:url) }

      it 'validates url format with http' do
        link = build(:website_link, url: 'http://example.com')
        expect(link).to be_valid
      end

      it 'validates url format with https' do
        link = build(:website_link, url: 'https://example.com')
        expect(link).to be_valid
      end

      it 'rejects invalid url format' do
        link = build(:website_link, url: 'not-a-valid-url')
        expect(link).not_to be_valid
        expect(link.errors[:url]).to be_present
      end

      it 'rejects url without protocol' do
        link = build(:website_link, url: 'example.com')
        expect(link).not_to be_valid
        expect(link.errors[:url]).to be_present
      end

      it 'rejects ftp protocol' do
        link = build(:website_link, url: 'ftp://example.com')
        expect(link).not_to be_valid
        expect(link.errors[:url]).to be_present
      end
    end

    describe 'labelable concern' do
      it 'includes Labelable concern' do
        expect(described_class.included_modules).to include(BetterTogether::Labelable)
      end

      it 'defines LABELS constant' do
        expect(described_class::LABELS).to be_a(Array)
        expect(described_class::LABELS).not_to be_empty
      end

      it 'includes expected label types' do
        expected_labels = %i[
          personal_website blog portfolio resume company_website community_page
          product_page services support contact_us about_us events donations careers
          privacy_policy terms_of_service faq forum documentation newsletter other
        ]
        expect(described_class::LABELS).to eq(expected_labels)
      end

      it 'can be created with different label values' do
        %i[blog portfolio company_website documentation].each do |label_value|
          link = create(:website_link, label: label_value.to_s)
          expect(link.label).to eq(label_value.to_s)
        end
      end
    end

    describe 'privacy concern' do
      it 'includes Privacy concern' do
        expect(described_class.included_modules).to include(BetterTogether::Privacy)
      end

      it 'has default privacy level' do
        link = create(:website_link)
        expect(link.privacy).to eq('public')
      end

      it 'can be set to private' do
        link = create(:website_link, :private)
        expect(link.privacy).to eq('private')
      end
    end

    describe 'touch behavior' do
      it 'touches contact_detail when updated' do
        link = create(:website_link)
        contact_detail = link.contact_detail

        expect do
          link.update(url: 'https://newurl.com')
        end.to(change { contact_detail.reload.updated_at })
      end
    end
  end
end
