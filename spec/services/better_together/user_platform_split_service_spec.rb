# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::UserPlatformSplitService do
  let!(:host_platform) { configure_host_platform }
  let(:tenant_platform) { create(:better_together_platform) }
  let(:role) { BetterTogether::Role.find_by!(identifier: 'platform_manager') }
  let!(:user) { create(:better_together_user, :confirmed, platform: host_platform) }

  before do
    BetterTogether::PersonPlatformMembership.create!(member: user.person, joinable: tenant_platform,
                                                     role:, status: 'active')
  end

  it 'reports without changing anything on a dry run', :aggregate_failures do
    plans = nil
    expect { plans = described_class.call }.not_to change(BetterTogether::User, :count)
    expect(plans.map(&:status)).to eq([:pending])
    expect(plans.first.target_platform_id).to eq(tenant_platform.id)
  end

  it 'creates a separate account on the other platform without copying the password', :aggregate_failures do
    expect { described_class.call(dry_run: false, mailer: false) }.to change(BetterTogether::User, :count).by(1)

    split = BetterTogether::User.find_by(platform: tenant_platform, email: user.email)
    expect(split.encrypted_password).not_to eq(user.encrypted_password)
    expect(split.person.platform_id).to eq(tenant_platform.id)
    expect(BetterTogether::PersonPlatformMembership.find_by(joinable: tenant_platform).member).to eq(split.person)
  end

  it 'is idempotent and leaves no cross-platform references', :aggregate_failures do
    described_class.call(dry_run: false, mailer: false)

    expect { described_class.call(dry_run: false, mailer: false) }.not_to change(BetterTogether::User, :count)
    expect(described_class.new.verification_failures).to be_empty
  end
end
