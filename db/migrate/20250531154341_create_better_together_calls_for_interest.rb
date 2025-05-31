class CreateBetterTogetherCallsForInterest < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :calls_for_interest do |t|
      t.string :type, null: false, default: 'BetterTogether::CallForInterest'
      t.bt_creator
      t.bt_identifier
      t.bt_privacy

      t.bt_references :interestable, polymorphic: true, null: true

      t.datetime :starts_at, index: { name: 'bt_calls_for_interest_by_starts_at' }
      t.datetime :ends_at, index: { name: 'bt_calls_for_interest_by_ends_at' }
    end
  end
end
