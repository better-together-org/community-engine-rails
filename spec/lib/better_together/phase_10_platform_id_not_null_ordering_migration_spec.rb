# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260616003001_add_platform_id_to_phase_10_extended_isolation')
require BetterTogether::Engine.root.join('db/migrate/20260616004001_backfill_platform_id_for_phase_10_extended')

RSpec.describe 'Phase 10 platform_id NOT NULL ordering' do # rubocop:disable RSpec/DescribeClass
  let(:not_null_migration) { AddPlatformIdToPhase10ExtendedIsolation.new }
  let(:backfill_migration) { BackfillPlatformIdForPhase10Extended.new }
  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    connection.change_column_null(:better_together_inbound_email_messages, :platform_id, true)
    example.run
    backfill_migration.send(:enforce_inbound_email_platform_id_not_null!)
  end

  it 'skips the NOT NULL constraint (with a warning) rather than hard-failing when a NULL row still exists' do
    message = create(:better_together_inbound_email_message)
    message.update_column(:platform_id, nil)

    expect { not_null_migration.change }.to output(/WARNING.*NULL platform_id/).to_stdout

    expect(message.reload.platform_id).to be_nil
  end

  it "the backfill migration's own enforcement step applies NOT NULL once every row is backfilled" do
    message = create(:better_together_inbound_email_message)
    message.update_column(:platform_id, nil)

    backfill_migration.up

    expect(
      connection.columns(:better_together_inbound_email_messages).find { |c| c.name == 'platform_id' }.null
    ).to be(false)
    expect(BetterTogether::InboundEmailMessage.where(platform_id: nil).count).to eq(0)
  end
end
