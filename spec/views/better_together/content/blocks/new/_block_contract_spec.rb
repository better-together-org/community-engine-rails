# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/new/_block.html.erb' do
  before do
    BetterTogether::Content::Block.load_all_subclasses
    view.define_singleton_method(:new_content_block_path) { |_options = {}| '/content/blocks/new' }
  end

  it 'renders the modern add-block picker partial for every addable block type' do
    BetterTogether::Content::Block.descendants.select(&:content_addable?).sort_by(&:name).each do |klass|
      render partial: 'better_together/content/blocks/new/block',
             locals: { block_type: klass }

      expect(rendered).to include(klass.model_name.human)
      expect(rendered).to include('/content/blocks/new')
    end
  end
end
