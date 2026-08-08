# frozen_string_literal: true

class CreateBetterTogetherBillingBenefitCredits < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_billing_benefit_credits)

    create_bt_table :billing_benefit_credits do |t|
      t.references :beneficiary,
                   type: :uuid,
                   polymorphic: true,
                   null: false
      t.references :sponsor,
                   type: :uuid,
                   polymorphic: true,
                   null: true
      t.references :sponsorship,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :better_together_billing_sponsorships }
      t.references :related_record,
                   type: :uuid,
                   polymorphic: true,
                   null: true
      t.string :benefit_key, null: false
      t.integer :quantity, null: false
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_billing_benefit_credits,
              %i[beneficiary_type beneficiary_id benefit_key],
              name: 'idx_bt_billing_benefit_credits_beneficiary_key'
  end
end
