# frozen_string_literal: true

class AddLifecycleFieldsToBetterTogetherAgreements < ActiveRecord::Migration[7.2]
  TABLE = :better_together_agreements
  LIFECYCLE_INDEX = :index_better_together_agreements_on_lifecycle_state

  def up
    add_column TABLE, :lifecycle_state, :string, null: false, default: 'active' unless column_exists?(TABLE, :lifecycle_state)
    add_column TABLE, :requires_reacceptance, :boolean, null: false, default: false unless column_exists?(TABLE, :requires_reacceptance)
    add_column TABLE, :change_summary, :text unless column_exists?(TABLE, :change_summary)

    add_index TABLE, :lifecycle_state, name: LIFECYCLE_INDEX unless index_exists?(TABLE, :lifecycle_state, name: LIFECYCLE_INDEX)
  end

  def down
    remove_index TABLE, name: LIFECYCLE_INDEX if index_exists?(TABLE, :lifecycle_state, name: LIFECYCLE_INDEX)

    remove_column TABLE, :change_summary if column_exists?(TABLE, :change_summary)
    remove_column TABLE, :requires_reacceptance if column_exists?(TABLE, :requires_reacceptance)
    remove_column TABLE, :lifecycle_state if column_exists?(TABLE, :lifecycle_state)
  end
end
