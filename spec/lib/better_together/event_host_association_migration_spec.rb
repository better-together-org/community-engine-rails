# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260530193000_require_event_host_associations')

RSpec.describe 'Event host association migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { RequireEventHostAssociations.new }

  after do
    migration.down
  end

  it 'removes unrepairable rows and enforces required columns idempotently' do
    # The dummy app's schema already reflects this migration having run (columns are
    # NOT NULL from the start), so relax the constraints first to recreate the
    # pre-migration state before inserting a deliberately invalid (all-NULL) row.
    migration.down

    valid_event_host = create(:better_together_event_host)
    invalid_id = SecureRandom.uuid

    insert_invalid_event_host(invalid_id)

    expect { migration.up }.to change(BetterTogether::EventHost, :count).by(-1)
    expect(BetterTogether::EventHost.exists?(valid_event_host.id)).to be(true)
    expect(BetterTogether::EventHost.exists?(invalid_id)).to be(false)
    expect(required_columns).to all(have_attributes(null: false))

    expect { migration.up }.not_to change(BetterTogether::EventHost, :count)
  end

  private

  def insert_invalid_event_host(invalid_id)
    connection = ActiveRecord::Base.connection
    timestamp = connection.quote(Time.current)

    connection.execute <<~SQL.squish
      INSERT INTO better_together_event_hosts
        (id, lock_version, created_at, updated_at, event_id, host_type, host_id)
      VALUES
        (#{connection.quote(invalid_id)}, 0, #{timestamp}, #{timestamp}, NULL, NULL, NULL)
    SQL
  end

  def required_columns
    ActiveRecord::Base.connection.columns(:better_together_event_hosts).select do |column|
      %w[event_id host_type host_id].include?(column.name)
    end
  end
end
