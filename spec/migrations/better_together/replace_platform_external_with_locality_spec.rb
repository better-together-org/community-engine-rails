# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261116200200_replace_platform_external_with_locality')

RSpec.describe ReplacePlatformExternalWithLocality, :no_auth do
  let!(:host_platform) { configure_host_platform }
  let!(:peer) { create(:platform, :remote, identifier: 'peer-locality') }
  let(:connection) { ActiveRecord::Base.connection }

  def migrate(direction)
    connection.execute('SET CONSTRAINTS ALL IMMEDIATE') # flush deferred FK checks before DDL
    ActiveRecord::Migration.suppress_messages { described_class.new.public_send(direction) }
    BetterTogether::Platform.reset_column_information
  end

  it 'restores the external boolean from locality on rollback' do
    migrate(:down)

    expect(connection.column_exists?(:better_together_platforms, :locality)).to be false
    expect(connection.select_value("SELECT external FROM better_together_platforms WHERE id = '#{peer.id}'")).to be true
    expect(connection.select_value("SELECT external FROM better_together_platforms WHERE id = '#{host_platform.id}'")).to be false
  end

  it 'backfills locality from external and drops the boolean', :aggregate_failures do
    migrate(:down)
    migrate(:up)

    expect(connection.column_exists?(:better_together_platforms, :external)).to be false
    expect(BetterTogether::Platform.find(peer.id).locality).to eq('remote')
    expect(BetterTogether::Platform.find(host_platform.id).locality).to eq('local')
  end
end
