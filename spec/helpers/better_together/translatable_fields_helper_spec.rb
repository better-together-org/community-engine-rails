# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe TranslatableFieldsHelper do
    before do
      helper.extend(BetterTogether::Content::BlocksHelper)
    end

    describe '#translatable_text_field_config' do
      let(:page) { build(:page) }

      it 'builds base options and data attributes' do
        expect(helper).to receive(:temp_id_for)
          .with(page, temp_id: 'temp-123')
          .and_return('resolved-123')

        config = helper.translatable_text_field_config(
          model: page,
          scope: 'better_together/content_block',
          temp_id: 'temp-123',
          attribute: 'title',
          rows: 4,
          help_text: 'Help text',
          input_options: {
            class: 'custom-class',
            data: { action: 'input->custom#track', foo: 'bar' }
          }
        )

        expect(config[:temp_id]).to eq('resolved-123')
        expect(config[:base_options][:rows]).to eq(4)
        expect(config[:base_options][:data]).to include(
          action: 'input->better_together--translation#updateTranslationStatus input->custom#track',
          'better-together-translation-target': 'input',
          foo: 'bar'
        )
        expect(config[:base_class]).to eq('form-control custom-class')
      end

      it 'uses default action when input options are nil' do
        allow(helper).to receive(:temp_id_for).and_return('resolved-456')

        config = helper.translatable_text_field_config(
          model: page,
          scope: 'better_together/content_block',
          temp_id: 'temp-456',
          attribute: 'title',
          rows: nil,
          help_text: nil,
          input_options: nil
        )

        expect(config[:base_options][:data][:action]).to eq(
          'input->better_together--translation#updateTranslationStatus'
        )
      end
    end

    describe '#translatable_text_field_options' do
      let(:page) { build(:page) }

      it 'adds validation class when errors exist' do
        allow(helper).to receive(:temp_id_for).and_return('resolved-789')
        page.errors.add(:title_en, 'cannot be blank')

        config = helper.translatable_text_field_config(
          model: page,
          scope: 'better_together/content_block',
          temp_id: 'temp-789',
          attribute: 'title',
          rows: 2,
          help_text: nil,
          input_options: { class: 'custom-class' }
        )

        options = helper.translatable_text_field_options(config, :title_en)

        expect(options[:id]).to eq("#{helper.dom_id(page)}-title_en")
        expect(options[:class]).to include('form-control')
        expect(options[:class]).to include('custom-class')
        expect(options[:class]).to include('is-invalid')
      end
    end
  end
end
