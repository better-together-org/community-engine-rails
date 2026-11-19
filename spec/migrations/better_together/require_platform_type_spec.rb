# frozen_string_literal: true

require 'rails_helper'

require BetterTogether::Engine.root.join('db/migrate/20261116200100_require_platform_type')

RSpec.describe RequirePlatformType, :no_auth do
  let!(:host_platform) { configure_host_platform }
  let!(:hosted) { untyped(create(:platform, locality: 'local')) }
  let!(:peer) { untyped(create(:platform, :remote, identifier: 'peer-communityengine')) }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.public_send(direction) }
  end

  def untyped(platform)
    ActiveRecord::Base.connection.execute('SET CONSTRAINTS ALL IMMEDIATE')
    ActiveRecord::Base.connection.change_column_null(:better_together_platforms, :type, true)
    platform.update_columns(type: nil) # rubocop:disable Rails/SkipsModelValidations
    platform
  end

  def type_of(platform)
    BetterTogether::Platform.where(id: platform.id).pick(:type)
  end

  after { migrate(:up) } # leave the column required, as the schema defines it

  it 'does not require another migration file by its original name (host apps rename copies)' do
    source = File.read(BetterTogether::Engine.root.join('db/migrate/20261116200100_require_platform_type.rb'))

    expect(source).not_to match(/require(_relative)?\s+['"]\d{14}_/)
  end

  it 'classifies rows still missing a type and makes the column required', :aggregate_failures do
    untyped(host_platform)

    migrate(:up)

    expect(type_of(host_platform)).to eq('BetterTogether::OperatorPlatform')
    expect(type_of(hosted)).to eq('BetterTogether::HostedPlatform')
    expect(type_of(peer)).to eq('BetterTogether::FederatedPlatform')
    column = BetterTogether::Platform.columns_hash['type']
    BetterTogether::Platform.reset_column_information
    expect(BetterTogether::Platform.columns_hash['type'].null).to be(false), "was #{column.null}"
  end

  it 'makes the column optional again on rollback' do
    migrate(:down)
    BetterTogether::Platform.reset_column_information

    expect(BetterTogether::Platform.columns_hash['type'].null).to be true
  end
end
