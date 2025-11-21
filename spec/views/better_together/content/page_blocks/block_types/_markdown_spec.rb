# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/page_blocks/block_types/_markdown.html.erb', type: :view do
  let(:page) { build(:better_together_page) }
  let(:block_type) { BetterTogether::Content::Markdown }
  let(:new_block_path) { '/pages/page_blocks/new' }

  before do
    view.define_singleton_method(:new_page_page_block_path) { |_page, **_options| } # stub target

    allow(view)
      .to receive(:new_page_page_block_path)
      .with(page, block_type: block_type.model_name.to_s)
      .and_return(new_block_path)
  end

  it 'renders an accessible link for Markdown blocks' do
    render partial: 'better_together/content/page_blocks/block_types/markdown',
           locals: { page:, block_type: }

    expect(rendered).to include(new_block_path)
    expect(rendered).to include('Create a new Markdown block for the page')
    expect(rendered).to include('fab fa-markdown')
    expect(rendered).to include('data-turbo-stream="true"')
  end
end
