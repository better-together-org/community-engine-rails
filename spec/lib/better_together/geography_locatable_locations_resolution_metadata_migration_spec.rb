# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260715120100_add_resolution_metadata_to_better_together_geography_locatable_locations'
)

RSpec.describe 'Add resolution metadata to locatable_locations migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration_class) { AddResolutionMetadataToBetterTogetherGeographyLocatableLocations }
  let(:connection) { ActiveRecord::Base.connection }
  let(:table) { :better_together_geography_locatable_locations }
  let(:index_name) { 'index_locatable_locations_on_locatable_and_location_type' }

  it 'dedups pre-existing duplicate rows before (re-)enforcing the unique index' do
    connection.remove_index(table, name: index_name)
    connection.schema_cache.clear_data_source_cache!(table.to_s)

    address = create(:better_together_address)
    settlement = create(:geography_settlement)

    older = BetterTogether::Geography::LocatableLocation.create!(
      locatable: address, location: settlement, resolution_method: 'polygon', resolved_at: 2.days.ago
    )
    older.update_column(:created_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations

    newer = BetterTogether::Geography::LocatableLocation.create!(
      locatable: address, location: settlement, resolution_method: 'polygon', resolved_at: 1.hour.ago
    )

    expect(
      BetterTogether::Geography::LocatableLocation.where(locatable: address, location: settlement).count
    ).to eq(2)

    # migration_class.migrate(:up), not migration.up — this Rails version's instance
    # #up delegates through a class-level check that only applies to migrations
    # defining explicit up/down methods; for change-only migrations like this one,
    # instance#up silently no-ops. .migrate(:up) is the form that actually runs #change.
    migration_class.migrate(:up)
    connection.schema_cache.clear_data_source_cache!(table.to_s)

    remaining = BetterTogether::Geography::LocatableLocation.where(locatable: address, location: settlement)
    expect(remaining.count).to eq(1)
    expect(remaining.first.id).to eq(newer.id)
    expect(BetterTogether::Geography::LocatableLocation.exists?(older.id)).to be(false)
    expect(connection.index_exists?(table, %i[locatable_type locatable_id location_type], name: index_name))
      .to be(true)
  end

  it 'is idempotent when re-run against an already-migrated schema' do
    expect { migration_class.migrate(:up) }.not_to raise_error
  end

  it 'logs every doomed row before deleting it, so a bad "keep the newest" choice is traceable' do
    connection.remove_index(table, name: index_name)
    connection.schema_cache.clear_data_source_cache!(table.to_s)

    address = create(:better_together_address)
    settlement = create(:geography_settlement)

    older = BetterTogether::Geography::LocatableLocation.create!(
      locatable: address, location: settlement, resolution_method: 'polygon', resolved_at: 2.days.ago
    )
    older.update_column(:created_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
    BetterTogether::Geography::LocatableLocation.create!(
      locatable: address, location: settlement, resolution_method: 'polygon', resolved_at: 1.hour.ago
    )

    expect(Rails.logger).to receive(:warn).with(a_string_including(
                                                  'AddResolutionMetadataToBetterTogetherGeographyLocatableLocations', "id=#{older.id}",
                                                  "locatable=#{address.class.name}##{address.id}", 'location_type=BetterTogether::Geography::Settlement'
                                                ))

    migration_class.migrate(:up)
    connection.schema_cache.clear_data_source_cache!(table.to_s)
  end
end
