# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/page_blocks/block_types/_alert_block.html.erb' do
  let(:page) { build(:better_together_page) }
  let(:block_type) { BetterTogether::Content::AlertBlock }
  let(:new_block_path) { '/pages/page_blocks/new' }

  before do
    view.define_singleton_method(:new_page_page_block_path) { |_page, **_options| nil }

    allow(view)
      .to receive(:new_page_page_block_path)
      .with(page, block_type: block_type.model_name.to_s)
      .and_return(new_block_path)
  end

  it 'renders a block-specific label instead of the generic block fallback' do
    render partial: 'better_together/content/page_blocks/block_types/alert_block',
           locals: { page:, block_type: }

    expect(rendered).to include(new_block_path)
    expect(rendered).to include('Create a new Alert block for the page')
    expect(rendered).to include('Alert icon')
    expect(rendered).to include('fas fa-exclamation-triangle')
    expect(rendered).not_to include('Create a new Block block for the page')
  end
end
