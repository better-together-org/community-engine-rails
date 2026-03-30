# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/page_blocks/block_types/_iframe_block.html.erb' do
  let(:page) { build(:better_together_page) }
  let(:block_type) { BetterTogether::Content::IframeBlock }
  let(:new_block_path) { '/pages/page_blocks/new' }

  before do
    view.define_singleton_method(:new_page_page_block_path) { |_page, **_options| nil }

    allow(view)
      .to receive(:new_page_page_block_path)
      .with(page, block_type: block_type.model_name.to_s)
      .and_return(new_block_path)
  end

  it 'renders an accessible link for Iframe blocks' do
    render partial: 'better_together/content/page_blocks/block_types/iframe_block',
           locals: { page:, block_type: }

    expect(rendered).to include(new_block_path)
    expect(rendered).to include('Create a new Iframe block for the page')
    expect(rendered).to include('fas fa-window-maximize')
    expect(rendered).to include('data-turbo-stream="true"')
  end
end
