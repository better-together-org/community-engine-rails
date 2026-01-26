# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::Template do
  describe 'associations' do
    it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
    it { is_expected.to have_many(:pages).through(:page_blocks) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:template_path) }

    it 'validates template_path is in available_templates list' do
      template = described_class.new(template_path: 'invalid/path')
      expect(template).not_to be_valid
      expect(template.errors[:template_path]).to include('is not included in the list')
    end

    it 'accepts valid template paths' do
      described_class.available_templates.each do |valid_path|
        template = described_class.new(template_path: valid_path)
        template.valid?
        expect(template.errors[:template_path]).to be_empty
      end
    end
  end

  describe 'available_templates' do
    it 'includes static page templates' do
      expect(described_class.available_templates).to include(
        'better_together/static_pages/privacy',
        'better_together/static_pages/terms_of_service',
        'better_together/static_pages/code_of_conduct',
        'better_together/static_pages/accessibility',
        'better_together/static_pages/cookie_consent'
      )
    end

    it 'includes contributor agreement templates' do
      expect(described_class.available_templates).to include(
        'better_together/static_pages/code_contributor_agreement',
        'better_together/static_pages/content_contributor_agreement'
      )
    end

    it 'includes other static pages' do
      expect(described_class.available_templates).to include(
        'better_together/static_pages/faq',
        'better_together/static_pages/better_together',
        'better_together/static_pages/community_engine',
        'better_together/static_pages/subprocessors'
      )
    end

    it 'includes content block templates' do
      expect(described_class.available_templates).to include(
        'better_together/content/blocks/template/default',
        'better_together/content/blocks/template/host_community_contact_details'
      )
    end
  end

  describe '#as_indexed_json' do
    let(:template) do
      described_class.create!(
        template_path: 'better_together/static_pages/privacy'
      )
    end

    it 'returns a hash with id and localized_content' do
      result = template.as_indexed_json

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly(:id, :localized_content)
    end

    it 'includes the template id' do
      result = template.as_indexed_json

      expect(result[:id]).to eq(template.id)
    end

    it 'includes localized content' do
      result = template.as_indexed_json

      expect(result[:localized_content]).to be_a(Hash)
      expect(result[:localized_content].keys).to match_array(I18n.available_locales)
    end
  end

  describe '#indexed_localized_content' do
    let(:template) do
      described_class.create!(
        template_path: 'better_together/static_pages/privacy'
      )
    end

    it 'returns a hash of locale to rendered content' do
      result = template.indexed_localized_content

      expect(result).to be_a(Hash)
      expect(result.keys).to match_array(I18n.available_locales)
    end

    it 'renders content for each locale' do
      result = template.indexed_localized_content

      I18n.available_locales.each do |locale|
        expect(result[locale]).to be_a(String)
        expect(result[locale]).not_to be_empty
      end
    end

    it 'returns plain text without HTML tags' do
      result = template.indexed_localized_content

      result.each_value do |content|
        expect(content).not_to match(/<[^>]+>/)
      end
    end

    it 'extracts meaningful text from templates' do
      result = template.indexed_localized_content

      expect(result[:en]).to include('Better Together')
      expect(result[:en]).to include('privacy')
    end

    it 'uses TemplateRendererService' do
      expect(BetterTogether::TemplateRendererService).to receive(:new)
        .with(template.template_path)
        .and_call_original

      template.indexed_localized_content
    end

    context 'with different template paths' do
      it 'renders privacy policy content' do
        template.update!(template_path: 'better_together/static_pages/privacy')
        result = template.indexed_localized_content

        expect(result[:en]).to include('privacy')
      end

      it 'renders terms of service content' do
        template.update!(template_path: 'better_together/static_pages/terms_of_service')
        result = template.indexed_localized_content

        expect(result[:en]).not_to be_empty
      end

      it 'renders content block templates' do
        template.update!(template_path: 'better_together/content/blocks/template/default')
        result = template.indexed_localized_content

        expect(result[:en]).to be_a(String)
      end
    end
  end

  describe 'integration with Page model' do
    let(:page) do
      BetterTogether::Page.create!(
        title: 'Test Page',
        slug: 'test-page',
        privacy: 'public',
        page_blocks_attributes: [
          {
            block_attributes: {
              type: 'BetterTogether::Content::Template',
              template_path: 'better_together/static_pages/privacy'
            }
          }
        ]
      )
    end

    it 'can be associated with pages through page_blocks' do
      expect(page.template_blocks.count).to eq(1)
      expect(page.template_blocks.first).to be_a(described_class)
    end

    it 'is indexed when page is indexed' do
      indexed_data = page.as_indexed_json

      expect(indexed_data['template_blocks']).to be_present
      expect(indexed_data['template_blocks'].first['indexed_localized_content']).to be_present
    end
  end

  describe 'store_attributes' do
    it 'stores template_path in content_data' do
      template = described_class.new(template_path: 'better_together/static_pages/privacy')

      expect(template.content_data).to include('template_path')
    end
  end
end
