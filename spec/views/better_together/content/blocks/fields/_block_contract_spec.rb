# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/fields/_block.html.erb' do
  helper BetterTogether::Content::BlocksHelper
  helper BetterTogether::TranslatableFieldsHelper

  let(:scope) { 'page[page_blocks_attributes][0][block_attributes]' }
  let(:temp_id) { 'block-contract-spec' }
  let(:base_storext_keys) { BetterTogether::Content::Block.storext_definitions.keys.map(&:to_s) }
  let(:internal_nonlocalized_fields) do
    {
      'BetterTogether::Content::Html' => %w[html_content]
    }.freeze
  end

  before do
    BetterTogether::Content::Block.load_all_subclasses
    view.define_singleton_method(:current_person) { nil }
    view.define_singleton_method(:policy_scope) do |_scope|
      BetterTogether::Community.none
    end
    view.main_app.define_singleton_method(:rails_direct_uploads_url) do
      '/rails/active_storage/direct_uploads'
    end
    view.main_app.define_singleton_method(:rails_service_blob_url) do |*_args, **_options|
      '/rails/active_storage/blobs/test'
    end
    allow(BetterTogether::Upload).to receive(:with_creator).and_return([])
    allow(BetterTogether::Engine.routes.url_helpers).to receive(:ai_translate_path).and_return('/ai/translate')
  end

  def build_block_for(klass)
    klass.new
  end

  def expected_localized_attributes_for(klass)
    klass.respond_to?(:mobility_attributes) ? klass.mobility_attributes.map(&:to_s) : []
  end

  def expected_nonlocalized_attributes_for(klass)
    (attachment_names_for(klass) + storext_keys_for(klass)).uniq.sort - internal_nonlocalized_fields.fetch(klass.name, [])
  end

  def attachment_names_for(klass)
    klass.reflect_on_all_attachments.map { |attachment| attachment.name.to_s } - %w[background_image_file]
  end

  def storext_keys_for(klass)
    klass.storext_definitions.keys.map(&:to_s) - base_storext_keys
  end

  it 'renders every addable block editor and surfaces translated and non-translated block attributes' do
    BetterTogether::Content::Block.descendants.select(&:content_addable?).sort_by(&:name).each do |klass|
      block = build_block_for(klass)

      render partial: 'better_together/content/blocks/fields/block',
             locals: { block:, scope:, temp_id: }

      page = Capybara.string(rendered)

      expected_localized_attributes_for(klass).each do |attribute|
        I18n.available_locales.each do |locale|
          translated_field_error = "#{klass.name} is missing translated field #{attribute}_#{locale}"
          expect(page).to have_css(%([name="#{scope}[#{attribute}_#{locale}]"]), visible: :all), translated_field_error
        end
      end

      expected_nonlocalized_attributes_for(klass).each do |attribute|
        nontranslated_field_error = "#{klass.name} is missing non-translated field #{attribute}"
        expect(page).to have_css(%([name="#{scope}[#{attribute}]"]), visible: :all), nontranslated_field_error
      end
    end
  end
end
