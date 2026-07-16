# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260415001000_repair_pending_person_membership_statuses')

RSpec.describe 'Repair pending person membership statuses migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { RepairPendingPersonMembershipStatuses.new }

  it 'activates a pending platform membership when the platform does not gate joining' do
    open_platform = create(:better_together_platform, host: false, requires_invitation: false,
                                                      allow_membership_requests: false)
    membership = create(:better_together_person_platform_membership, joinable: open_platform, status: 'pending')

    migration.send(:backfill_platform_memberships)

    expect(membership.reload.status).to eq('active')
  end

  it 'leaves a pending platform membership pending when the platform requires invitation/approval' do
    gated_platform = create(:better_together_platform, host: false, requires_invitation: true)
    membership = create(:better_together_person_platform_membership, joinable: gated_platform, status: 'pending')

    migration.send(:backfill_platform_memberships)

    expect(membership.reload.status).to eq('pending')
  end
end
