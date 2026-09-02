# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260902180000_repair_local_content_scoped_to_external_platforms'
)

RSpec.describe 'Repair local content scoped to external platforms migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { RepairLocalContentScopedToExternalPlatforms.new }

  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host, :public) }
  let(:external_platform) { create(:better_together_platform, :external) }

  before { migration.verbose = false }

  def scope_to(record, platform)
    record.update_column(:platform_id, platform.id)
  end

  it 'reassigns a locally-authored page from an external platform back to the host platform' do
    page = create(:better_together_page)
    scope_to(page, external_platform)

    migration.up

    expect(page.reload.platform_id).to eq(host_platform.id)
  end

  it 'leaves a mirrored page (source_id present) on the external platform' do
    mirror = create(:better_together_page)
    mirror.update_columns(platform_id: external_platform.id, source_id: 'remote-123')

    migration.up

    expect(mirror.reload.platform_id).to eq(external_platform.id)
  end

  it 'reassigns navigation items stranded on an external platform' do
    area = create(:better_together_navigation_area)
    item = create(:better_together_navigation_item, navigation_area: area)
    scope_to(area, external_platform)
    scope_to(item, external_platform)

    migration.up

    expect(area.reload.platform_id).to eq(host_platform.id)
    expect(item.reload.platform_id).to eq(host_platform.id)
  end

  it 'realigns a content block to its owning page after the page is moved' do
    page = create(:better_together_page)
    block = create(:better_together_content_rich_text)
    create(:better_together_content_page_block, page: page, block: block)
    scope_to(page, external_platform)
    scope_to(block, external_platform)

    migration.up

    expect(page.reload.platform_id).to eq(host_platform.id)
    expect(block.reload.platform_id).to eq(host_platform.id)
  end

  it 'does not move a page whose identifier already exists on the host platform' do
    create(:better_together_page, identifier: 'shared-slug').tap { |p| scope_to(p, host_platform) }
    colliding = create(:better_together_page, identifier: 'shared-slug-tmp')
    colliding.update_columns(identifier: 'shared-slug', platform_id: external_platform.id)

    migration.up

    expect(colliding.reload.platform_id).to eq(external_platform.id)
  end

  it 'never touches content already scoped to the host platform' do
    external_platform # ensure at least one external platform exists
    host_page = create(:better_together_page)
    scope_to(host_page, host_platform)

    expect { migration.up }.not_to(change { host_page.reload.platform_id }.from(host_platform.id))
  end

  it 'is idempotent' do
    page = create(:better_together_page)
    scope_to(page, external_platform)

    migration.up
    expect { migration.up }.not_to(change { page.reload.platform_id })
  end
end
