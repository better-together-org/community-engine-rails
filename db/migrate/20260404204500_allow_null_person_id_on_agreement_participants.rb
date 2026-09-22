# frozen_string_literal: true

class AllowNullPersonIdOnAgreementParticipants < ActiveRecord::Migration[7.2]
  def up
    change_column_null :better_together_agreement_participants, :person_id, true if column_exists?(:better_together_agreement_participants,
                                                                                                   :person_id)
  end

  def down
    return unless column_exists?(:better_together_agreement_participants, :person_id)

    execute <<~SQL.squish
      DELETE FROM better_together_agreement_participants
      WHERE person_id IS NULL
    SQL
    change_column_null :better_together_agreement_participants, :person_id, false
  end
end
