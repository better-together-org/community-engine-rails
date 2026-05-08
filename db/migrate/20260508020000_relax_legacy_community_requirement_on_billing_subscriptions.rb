# frozen_string_literal: true

class RelaxLegacyCommunityRequirementOnBillingSubscriptions < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_billing_subscriptions)
    return unless column_exists?(:better_together_billing_subscriptions, :community_id)

    change_column_null :better_together_billing_subscriptions, :community_id, true
  end

  def down
    return unless table_exists?(:better_together_billing_subscriptions)
    return unless column_exists?(:better_together_billing_subscriptions, :community_id)

    if BetterTogether::Billing::Subscription.where(community_id: nil).exists?
      raise ActiveRecord::IrreversibleMigration,
            'Cannot restore NOT NULL on billing subscriptions.community_id while person-owned subscriptions exist.'
    end

    change_column_null :better_together_billing_subscriptions, :community_id, false
  end
end
