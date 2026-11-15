# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261115200300_add_platform_to_friendly_id_slugs')

# Slug rows gain a platform from their record, and duplicate history rows are set aside so the
# per-platform unique index can be built.
RSpec.describe AddPlatformToFriendlyIdSlugs, :no_auth do
  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let(:connection) { ActiveRecord::Base.connection }

  def run_migration
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  def slug_rows(record)
    FriendlyId::Slug.unscoped.where(sluggable_type: 'BetterTogether::Page', sluggable_id: record.id)
  end

  it 'backfills the platform of rows that lack one' do
    page = create(:better_together_page, platform: other_platform, slug: 'backfill-me')
    slug_rows(page).update_all(platform_id: nil) # rubocop:disable Rails/SkipsModelValidations

    run_migration

    expect(slug_rows(page).pluck(:platform_id).uniq).to eq([other_platform.id])
  end

  it 'is safe to run twice' do
    run_migration

    expect { run_migration }.not_to raise_error
  end

  it 'keeps the newest of duplicate rows and copies the others to a backup table', :aggregate_failures do
    connection.remove_index :friendly_id_slugs, name: described_class::NEW_INDEX
    older, newer = Array.new(2) { create(:better_together_page, platform: other_platform) }
    [older, newer].each { |page| slug_rows(page).update_all(slug: 'twin', platform_id: other_platform.id) } # rubocop:disable Rails/SkipsModelValidations

    run_migration

    expect(FriendlyId::Slug.unscoped.where(slug: 'twin', sluggable_type: 'BetterTogether::Page').pluck(:sluggable_id))
      .to eq([newer.id])
    expect(connection.select_value("SELECT count(*) FROM #{described_class::BACKUP_TABLE}").to_i).to eq(1)
    expect(connection.index_name_exists?(:friendly_id_slugs, described_class::NEW_INDEX)).to be(true)
  end

  it 'reverts to the old index and drops the column', :aggregate_failures do
    ActiveRecord::Migration.suppress_messages { described_class.new.down }

    expect(connection.column_exists?(:friendly_id_slugs, :platform_id)).to be(false)
    expect(connection.index_name_exists?(:friendly_id_slugs, described_class::OLD_INDEX)).to be(true)
    expect(connection.index_name_exists?(:friendly_id_slugs, described_class::NEW_INDEX)).to be(false)
  end
end
