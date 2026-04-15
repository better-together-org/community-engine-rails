# frozen_string_literal: true

class AddConsentMetadataToBetterTogetherAgreements < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_agreements)

    add_column_unless_exists :agreement_kind, :string, default: 'policy_consent', null: false
    add_column_unless_exists :required_for, :string, default: 'none', null: false
    add_column_unless_exists :active_for_consent, :boolean, default: true, null: false

    backfill_existing_agreement_metadata
  end

  def down
    return unless table_exists?(:better_together_agreements)

    remove_column :better_together_agreements, :active_for_consent if column_exists?(:better_together_agreements,
                                                                                     :active_for_consent)
    remove_column :better_together_agreements, :required_for if column_exists?(:better_together_agreements,
                                                                               :required_for)
    remove_column :better_together_agreements, :agreement_kind if column_exists?(:better_together_agreements,
                                                                                 :agreement_kind)
  end

  private

  def add_column_unless_exists(column_name, type, **options)
    return if column_exists?(:better_together_agreements, column_name)

    add_column :better_together_agreements, column_name, type, **options
  end

  def backfill_existing_agreement_metadata
    say_with_time 'Backfilling agreement consent metadata' do
      execute <<~SQL.squish
        UPDATE better_together_agreements
        SET agreement_kind = CASE identifier
          WHEN 'content_publishing_agreement' THEN 'publishing_consent'
          ELSE 'policy_consent'
        END,
            required_for = CASE identifier
          WHEN 'privacy_policy' THEN 'registration'
          WHEN 'terms_of_service' THEN 'registration'
          WHEN 'code_of_conduct' THEN 'registration'
          WHEN 'content_publishing_agreement' THEN 'first_publish'
          ELSE 'none'
        END,
            active_for_consent = TRUE
      SQL
    end
  end
end
