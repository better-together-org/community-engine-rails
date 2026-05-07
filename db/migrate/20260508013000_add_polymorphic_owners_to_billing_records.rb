# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

class AddPolymorphicOwnersToBillingRecords < ActiveRecord::Migration[7.2]
  def up
    add_subscription_owner_columns
    add_event_owner_columns
    backfill_subscription_owner_columns
    backfill_event_owner_columns
  end

  def down
    remove_event_owner_columns
    remove_subscription_owner_columns
  end

  private

  # rubocop:disable Metrics/CyclomaticComplexity
  def add_subscription_owner_columns
    return unless table_exists?(:better_together_billing_subscriptions)

    add_column :better_together_billing_subscriptions, :billable_owner_type, :string unless column_exists?(
      :better_together_billing_subscriptions, :billable_owner_type
    )
    add_column :better_together_billing_subscriptions, :billable_owner_id, :uuid unless column_exists?(
      :better_together_billing_subscriptions, :billable_owner_id
    )
    add_column :better_together_billing_subscriptions, :beneficiary_type, :string unless column_exists?(
      :better_together_billing_subscriptions, :beneficiary_type
    )
    add_column :better_together_billing_subscriptions, :beneficiary_id, :uuid unless column_exists?(
      :better_together_billing_subscriptions, :beneficiary_id
    )

    unless index_exists?(:better_together_billing_subscriptions, %i[billable_owner_type billable_owner_id],
                         name: 'idx_bt_billing_subscriptions_owner')
      add_index :better_together_billing_subscriptions,
                %i[billable_owner_type billable_owner_id],
                name: 'idx_bt_billing_subscriptions_owner'
    end

    unless index_exists?(:better_together_billing_subscriptions, %i[beneficiary_type beneficiary_id],
                         name: 'idx_bt_billing_subscriptions_beneficiary')
      add_index :better_together_billing_subscriptions,
                %i[beneficiary_type beneficiary_id],
                name: 'idx_bt_billing_subscriptions_beneficiary'
    end
  end

  def add_event_owner_columns
    return unless table_exists?(:better_together_billing_events)

    add_column :better_together_billing_events, :billable_owner_type, :string unless column_exists?(
      :better_together_billing_events, :billable_owner_type
    )
    add_column :better_together_billing_events, :billable_owner_id, :uuid unless column_exists?(
      :better_together_billing_events, :billable_owner_id
    )
    add_column :better_together_billing_events, :beneficiary_type, :string unless column_exists?(
      :better_together_billing_events, :beneficiary_type
    )
    add_column :better_together_billing_events, :beneficiary_id, :uuid unless column_exists?(
      :better_together_billing_events, :beneficiary_id
    )

    unless index_exists?(:better_together_billing_events, %i[billable_owner_type billable_owner_id],
                         name: 'idx_bt_billing_events_owner')
      add_index :better_together_billing_events,
                %i[billable_owner_type billable_owner_id],
                name: 'idx_bt_billing_events_owner'
    end

    unless index_exists?(:better_together_billing_events, %i[beneficiary_type beneficiary_id],
                         name: 'idx_bt_billing_events_beneficiary')
      add_index :better_together_billing_events,
                %i[beneficiary_type beneficiary_id],
                name: 'idx_bt_billing_events_beneficiary'
    end
  end

  def backfill_subscription_owner_columns
    return unless table_exists?(:better_together_billing_subscriptions)
    return unless column_exists?(:better_together_billing_subscriptions, :community_id)

    execute <<~SQL.squish
      UPDATE better_together_billing_subscriptions
      SET billable_owner_type = COALESCE(billable_owner_type, 'BetterTogether::Community'),
          billable_owner_id = COALESCE(billable_owner_id, community_id),
          beneficiary_type = COALESCE(beneficiary_type, 'BetterTogether::Community'),
          beneficiary_id = COALESCE(beneficiary_id, community_id)
      WHERE community_id IS NOT NULL
    SQL
  end

  def backfill_event_owner_columns
    return unless table_exists?(:better_together_billing_events)
    return unless column_exists?(:better_together_billing_events, :community_id)

    execute <<~SQL.squish
      UPDATE better_together_billing_events
      SET billable_owner_type = COALESCE(billable_owner_type, 'BetterTogether::Community'),
          billable_owner_id = COALESCE(billable_owner_id, community_id),
          beneficiary_type = COALESCE(beneficiary_type, 'BetterTogether::Community'),
          beneficiary_id = COALESCE(beneficiary_id, community_id)
      WHERE community_id IS NOT NULL
    SQL
  end

  def remove_subscription_owner_columns
    return unless table_exists?(:better_together_billing_subscriptions)

    remove_index :better_together_billing_subscriptions, name: 'idx_bt_billing_subscriptions_owner' if index_exists?(
      :better_together_billing_subscriptions, name: 'idx_bt_billing_subscriptions_owner'
    )
    if index_exists?(:better_together_billing_subscriptions, name: 'idx_bt_billing_subscriptions_beneficiary')
      remove_index :better_together_billing_subscriptions,
                   name: 'idx_bt_billing_subscriptions_beneficiary'
    end
    remove_column :better_together_billing_subscriptions, :billable_owner_type if column_exists?(
      :better_together_billing_subscriptions, :billable_owner_type
    )
    remove_column :better_together_billing_subscriptions, :billable_owner_id if column_exists?(
      :better_together_billing_subscriptions, :billable_owner_id
    )
    remove_column :better_together_billing_subscriptions, :beneficiary_type if column_exists?(
      :better_together_billing_subscriptions, :beneficiary_type
    )
    remove_column :better_together_billing_subscriptions, :beneficiary_id if column_exists?(
      :better_together_billing_subscriptions, :beneficiary_id
    )
  end

  def remove_event_owner_columns
    return unless table_exists?(:better_together_billing_events)

    remove_index :better_together_billing_events, name: 'idx_bt_billing_events_owner' if index_exists?(
      :better_together_billing_events, name: 'idx_bt_billing_events_owner'
    )
    remove_index :better_together_billing_events, name: 'idx_bt_billing_events_beneficiary' if index_exists?(
      :better_together_billing_events, name: 'idx_bt_billing_events_beneficiary'
    )
    remove_column :better_together_billing_events, :billable_owner_type if column_exists?(
      :better_together_billing_events, :billable_owner_type
    )
    remove_column :better_together_billing_events, :billable_owner_id if column_exists?(
      :better_together_billing_events, :billable_owner_id
    )
    remove_column :better_together_billing_events, :beneficiary_type if column_exists?(
      :better_together_billing_events, :beneficiary_type
    )
    remove_column :better_together_billing_events, :beneficiary_id if column_exists?(
      :better_together_billing_events, :beneficiary_id
    )
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
# rubocop:enable Metrics/ClassLength
