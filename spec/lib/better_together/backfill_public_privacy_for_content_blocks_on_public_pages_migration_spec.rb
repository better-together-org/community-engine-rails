# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260902190000_backfill_public_privacy_for_content_blocks_on_public_pages'
)

RSpec.describe 'Backfill public privacy for content blocks on public pages migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { BackfillPublicPrivacyForContentBlocksOnPublicPages.new }

  before { migration.verbose = false }

  def block_on(page, privacy: 'private', visible: true)
    block = create(:better_together_content_rich_text)
    block.update_columns(privacy: privacy, visible: visible)
    create(:better_together_content_page_block, page: page, block: block)
    block
  end

  it 'makes a private visible block on a published public page public' do
    page = create(:better_together_page, privacy: 'public', published_at: 1.day.ago)
    block = block_on(page)

    migration.up

    expect(block.reload.privacy).to eq('public')
  end

  it 'leaves a block on a private page private' do
    page = create(:better_together_page, privacy: 'private', published_at: 1.day.ago)
    block = block_on(page)

    migration.up

    expect(block.reload.privacy).to eq('private')
  end

  it 'leaves a block on an unpublished public page private' do
    page = create(:better_together_page, privacy: 'public', published_at: nil)
    block = block_on(page)

    migration.up

    expect(block.reload.privacy).to eq('private')
  end

  it 'leaves a non-visible block private' do
    page = create(:better_together_page, privacy: 'public', published_at: 1.day.ago)
    block = block_on(page, visible: false)

    migration.up

    expect(block.reload.privacy).to eq('private')
  end

  it 'is idempotent' do
    page = create(:better_together_page, privacy: 'public', published_at: 1.day.ago)
    block = block_on(page)

    migration.up
    expect { migration.up }.not_to(change { block.reload.privacy })
  end
end
