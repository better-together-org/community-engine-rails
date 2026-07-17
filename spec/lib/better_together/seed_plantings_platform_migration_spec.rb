# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260717130000_add_platform_to_better_together_seed_plantings')

RSpec.describe 'Seed plantings platform migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { AddPlatformToBetterTogetherSeedPlantings.new }
  let(:connection) { ActiveRecord::Base.connection }

  before do
    migration.up unless connection.column_exists?(:better_together_seed_plantings, :platform_id)
  end

  after do
    migration.up unless connection.column_exists?(:better_together_seed_plantings, :platform_id)
  end

  it 'adds a nullable platform reference' do
    migration.down
    expect(connection.column_exists?(:better_together_seed_plantings, :platform_id)).to be(false)

    migration.up

    column = connection.columns(:better_together_seed_plantings).find { |c| c.name == 'platform_id' }
    expect(column).to have_attributes(null: true)
  end

  it 'is idempotent when run twice' do
    expect { migration.up }.not_to raise_error
  end
end
