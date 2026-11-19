# frozen_string_literal: true

require 'rails_helper'

# Guards every block picker partial (page-block picker and standalone block picker)
# against hardcoded English accessible names, so new blocks cannot regress.
RSpec.describe 'Block picker partial translations' do
  let(:page) { build(:better_together_page) }
  let(:addable_blocks) do
    BetterTogether::Content::Block.load_all_subclasses
    BetterTogether::Content::Block.descendants.select(&:content_addable?).sort_by(&:name)
  end

  before do
    allow(view).to receive_messages(new_page_page_block_path: '/pages/page_blocks/new',
                                    new_content_block_path: '/content/blocks/new')
  end

  %i[en fr es uk].each do |locale|
    it "localizes the accessible names of every picker partial in #{locale}" do
      I18n.with_locale(locale) do
        addable_blocks.each do |klass|
          render partial: 'better_together/content/page_blocks/block_types/block_type', locals: { page:, block_type: klass }
          page_picker = rendered
          render partial: 'better_together/content/blocks/new/block', locals: { block_type: klass }
          block_picker = rendered

          [page_picker, block_picker].each do |html|
            expect(html).not_to match(/translation missing|title="[^"]*\.(create|icon)/i), klass.name
            icon = I18n.t('better_together.content.block_picker.icon', block: klass.model_name.human)
            expect(html).to include(ERB::Util.html_escape(icon)), klass.name
            next if locale == :en

            expect(html).not_to include('Create a new'), klass.name
            expect(html).not_to match(/aria-label="[^"]* icon"/), klass.name
          end
        end
      end
    end
  end
end
