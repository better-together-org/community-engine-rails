# frozen_string_literal: true

# Creates join table between agreements and people
class CreateBetterTogetherAgreementParticipants < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :agreement_participants do |t|
      t.bt_references :agreement, null: false
      t.bt_references :person, null: false
      t.string :group_identifier
      t.datetime :accepted_at
    end
  end
end
