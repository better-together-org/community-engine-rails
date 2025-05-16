class CreateBetterTogetherAgreementTerms < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :agreement_terms do |t|
      t.bt_identifier
      t.bt_position
      t.bt_protected
      t.bt_references :agreement, target_table: :better_together_agreements, null: false
    end
  end
end
