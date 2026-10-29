# frozen_string_literal: true

require 'rails_helper'

# Person hard deletion with quota usage is covered in
# spec/services/better_together/person_hard_deletion_executor_spec.rb, which has the
# fixture a reviewed person deletion needs.
RSpec.describe BetterTogether::Quotas::Owner do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  def settle(owner:, key:)
    BetterTogether::Quotas.settle!(type: 'media_storage', owner:, amount: 100, idempotency_key: key)
  end

  it 'lets a community with recorded usage be destroyed, erasing its ledger' do
    community = create(:better_together_community)
    settle(owner: community, key: 'owner_spec:community')
    quota_id = BetterTogether::Quota.find_by(owner: community).id

    expect { community.destroy! }.not_to raise_error

    expect(BetterTogether::Quota.where(id: quota_id)).not_to exist
    expect(BetterTogether::QuotaUsage.where(quota_id:)).not_to exist
    expect(BetterTogether::QuotaBalance.where(quota_id:)).not_to exist
  end

  it 'still refuses to destroy a Quota row that has usage directly' do
    person = create(:better_together_person)
    settle(owner: person, key: 'owner_spec:direct')

    expect { BetterTogether::Quota.find_by(owner: person).destroy }
      .to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end
