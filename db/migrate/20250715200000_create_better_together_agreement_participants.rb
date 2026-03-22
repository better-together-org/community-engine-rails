# frozen_string_literal: true

# Creates join table between agreements and people
class CreateBetterTogetherAgreementParticipants < ActiveRecord::Migration[7.1]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :agreement_participants do |t|
      t.bt_references :agreement, null: false
      t.bt_references :person, null: false
      t.string :group_identifier
      t.datetime :accepted_at
    end

    add_index :better_together_agreement_participants,
              %i[agreement_id person_id],
              unique: true,
              name: 'index_bt_agreement_participants_on_agreement_and_person'
    add_index :better_together_agreement_participants, :group_identifier
  end
end
