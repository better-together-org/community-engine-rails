# frozen_string_literal: true

class AddPolymorphicParticipantToAgreementParticipants < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_column :better_together_agreement_participants, :participant_type, :string unless column_exists?(
      :better_together_agreement_participants, :participant_type
    )
    add_column :better_together_agreement_participants, :participant_id, :uuid unless column_exists?(:better_together_agreement_participants,
                                                                                                     :participant_id)

    execute <<~SQL.squish
      UPDATE better_together_agreement_participants
      SET participant_type = 'BetterTogether::Person', participant_id = person_id
      WHERE participant_type IS NULL AND person_id IS NOT NULL
    SQL

    enforce_participant_not_null!

    unless index_exists?(:better_together_agreement_participants,
                         %i[agreement_id participant_type
                            participant_id],
                         unique: true,
                         name: 'idx_better_together_agreement_participants_unique_participant')
      add_index :better_together_agreement_participants,
                %i[agreement_id participant_type participant_id],
                unique: true,
                algorithm: :concurrently,
                name: 'idx_better_together_agreement_participants_unique_participant'
    end
  end

  def down
    if index_exists?(:better_together_agreement_participants,
                     name: 'idx_better_together_agreement_participants_unique_participant')
      remove_index :better_together_agreement_participants,
                   name: 'idx_better_together_agreement_participants_unique_participant'
    end
    remove_column :better_together_agreement_participants, :participant_type if column_exists?(:better_together_agreement_participants,
                                                                                               :participant_type)
    remove_column :better_together_agreement_participants, :participant_id if column_exists?(:better_together_agreement_participants,
                                                                                             :participant_id)
  end

  private

  # The backfill above only covers rows where person_id was present — any row
  # with person_id also NULL (and thus still un-backfilled) would otherwise
  # make this hard-fail with no diagnostic. Warn and skip instead, matching
  # 20260321000004's established house style.
  def enforce_participant_not_null!
    null_count = execute(<<~SQL.squish).first['count'].to_i
      SELECT COUNT(*) FROM better_together_agreement_participants
      WHERE participant_type IS NULL OR participant_id IS NULL
    SQL

    if null_count.positive?
      say "WARNING: #{null_count} row(s) in better_together_agreement_participants " \
          'still have NULL participant_type/participant_id (no person_id to derive ' \
          'from). Skipping NOT NULL constraint — repair those rows and re-run.'
      return
    end

    change_column_null :better_together_agreement_participants, :participant_type, false
    change_column_null :better_together_agreement_participants, :participant_id, false
  end
end
