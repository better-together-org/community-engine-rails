# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260903151133_make_seeded_static_pages_and_blocks_public')

RSpec.describe 'MakeSeededStaticPagesAndBlocksPublic migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { MakeSeededStaticPagesAndBlocksPublic.new }

  def attach_private_block(page)
    block = create(:content_markdown)
    block.update_columns(privacy: 'private', visible: false)
    BetterTogether::Content::PageBlock.create!(page: page, block: block, position: page.page_blocks.count)
    block
  end

  it 'makes a seeded static page and its content blocks public and visible' do
    page = BetterTogether::Page.i18n.find_by(slug: 'privacy-policy') ||
           create(:better_together_page, slug_en: 'privacy-policy')
    page.update_columns(privacy: 'private')
    block = attach_private_block(page)

    migration.up

    expect(page.reload.privacy).to eq('public')
    expect(block.reload).to have_attributes(privacy: 'public', visible: true)
  end

  it 'does not touch a page whose slug is not a seeded static page' do
    page = create(:better_together_page, privacy: 'community', published_at: 1.day.ago)
    block = attach_private_block(page)

    migration.up

    expect(page.reload.privacy).to eq('community')
    expect(block.reload).to have_attributes(privacy: 'private', visible: false)
  end
end
