# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Image gallery and file download block picker translations' do
  let(:page) { build(:better_together_page) }
  let(:blocks) { [BetterTogether::Content::ImageGalleryBlock, BetterTogether::Content::FileDownloadBlock] }

  before { allow(view).to receive(:new_page_page_block_path).and_return('/pages/page_blocks/new') }

  %i[en fr es uk].each do |locale|
    it "localizes the page-block picker accessible names in #{locale}" do
      I18n.with_locale(locale) do
        blocks.each do |klass|
          render partial: 'better_together/content/page_blocks/block_types/block_type', locals: { page:, block_type: klass }

          expect(rendered).not_to match(/translation missing/i), klass.name
          expect(rendered).to include(ERB::Util.html_escape(I18n.t('better_together.content.block_picker.icon', block: klass.model_name.human))),
                              klass.name
          next if locale == :en

          expect(rendered).not_to include('Create a new'), klass.name
          expect(rendered).not_to match(/aria-label="[^"]* icon"/), klass.name
        end
      end
    end
  end
end
