# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/page_blocks/block_types/_block_type.html.erb' do
  let(:page) { build(:better_together_page) }

  before(:all) do
    BetterTogether::Content::Block.load_all_subclasses
  end

  before do
    view.define_singleton_method(:new_page_page_block_path) { |_page, **_options| }
    allow(view).to receive(:new_page_page_block_path).and_return('/pages/page_blocks/new')
  end

  it 'renders the legacy page-block picker partial for every addable block type' do
    BetterTogether::Content::Block.descendants.select(&:content_addable?).sort_by(&:name).each do |klass|
      render partial: 'better_together/content/page_blocks/block_types/block_type',
             locals: { page:, block_type: klass }

      expect(rendered).to include(klass.model_name.human)
      expect(rendered).to include('/pages/page_blocks/new')
    end
  end
end
