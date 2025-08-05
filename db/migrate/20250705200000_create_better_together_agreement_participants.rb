# frozen_string_literal: true

# Creates join records linking people to agreements
class CreateBetterTogetherAgreementParticipants < ActiveRecord::Migration[7.1]
  # rubocop:todo Metrics/MethodLength
  def change
    create_bt_table :agreement_participants do |t|
      t.bt_references :agreement, target_table: :better_together_agreements, null: false
      t.bt_references :person, target_table: :better_together_people, null: false
      t.string :group_identifier
    end

    add_index :better_together_agreement_participants,
              %i[agreement_id person_id],
              unique: true,
              name: 'index_bt_agreement_participants_on_agreement_and_person'
    add_index :better_together_agreement_participants, :group_identifier
  end
  # rubocop:enable Metrics/MethodLength
end
