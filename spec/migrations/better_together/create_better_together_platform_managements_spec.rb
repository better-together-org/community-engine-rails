# frozen_string_literal: true

require 'rails_helper'

require BetterTogether::Engine.root.join('db/migrate/20261123182850_create_better_together_platform_managements')

RSpec.describe CreateBetterTogetherPlatformManagements, :no_auth do
  let(:table) { :better_together_platform_managements }
  let(:connection) { ActiveRecord::Base.connection }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.public_send(direction) }
  end

  it 'creates the table with a unique edge index' do
    expect(connection.table_exists?(table)).to be true
    expect(connection.index_exists?(table, %i[operator_platform_id managed_platform_id], unique: true)).to be true
  end

  it 'is idempotent when the table already exists' do
    expect { migrate(:up) }.not_to raise_error
    expect(connection.table_exists?(table)).to be true
  end

  it 'is reversible and can be re-applied' do
    migrate(:down)
    expect(connection.table_exists?(table)).to be false
    expect { migrate(:down) }.not_to raise_error
    migrate(:up)
    expect(connection.table_exists?(table)).to be true
  end

  it 'restores a partially applied schema (table without indexes)' do
    connection.remove_index(table, name: 'idx_bt_platform_mgmt_edge_uid')
    migrate(:up)
    expect(connection.index_exists?(table, :edge_uid, unique: true)).to be true
  end
end
