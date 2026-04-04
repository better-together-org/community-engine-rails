# frozen_string_literal: true

class AddPolymorphicParticipantToAgreementParticipants < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_column :better_together_agreement_participants, :participant_type, :string unless column_exists?(:better_together_agreement_participants, :participant_type)
    add_column :better_together_agreement_participants, :participant_id, :uuid unless column_exists?(:better_together_agreement_participants, :participant_id)

    execute <<~SQL.squish
      UPDATE better_together_agreement_participants
      SET participant_type = 'BetterTogether::Person', participant_id = person_id
      WHERE participant_type IS NULL AND person_id IS NOT NULL
    SQL

    change_column_null :better_together_agreement_participants, :participant_type, false
    change_column_null :better_together_agreement_participants, :participant_id, false

    add_index :better_together_agreement_participants,
              %i[agreement_id participant_type participant_id],
              unique: true,
              algorithm: :concurrently,
              name: 'idx_better_together_agreement_participants_unique_participant' unless index_exists?(:better_together_agreement_participants,
                                                                                                         %i[agreement_id participant_type participant_id],
                                                                                                         unique: true,
                                                                                                         name: 'idx_better_together_agreement_participants_unique_participant')
  end

  def down
    remove_index :better_together_agreement_participants,
                 name: 'idx_better_together_agreement_participants_unique_participant' if index_exists?(:better_together_agreement_participants,
                                                                                                        name: 'idx_better_together_agreement_participants_unique_participant')
    remove_column :better_together_agreement_participants, :participant_type if column_exists?(:better_together_agreement_participants, :participant_type)
    remove_column :better_together_agreement_participants, :participant_id if column_exists?(:better_together_agreement_participants, :participant_id)
  end
end
