# frozen_string_literal: true

# Append-only audit trail for trusted domain changes and for accounts created through a trusted domain.
class CreateBetterTogetherTrustedDomainEvents < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_trusted_domain_events)

    create_bt_table :trusted_domain_events do |t|
      t.bt_references :platform, target_table: :better_together_platforms,
                                 index: { name: 'idx_bt_td_events_on_platform_id' }
      t.bt_references :platform_trusted_domain, target_table: :better_together_platform_trusted_domains,
                                                null: true, fk_options: { on_delete: :nullify },
                                                index: { name: 'idx_bt_td_events_on_domain_id' }
      t.bt_references :actor, target_table: :better_together_people, null: true,
                              fk_options: { on_delete: :nullify },
                              index: { name: 'idx_bt_td_events_on_actor_id' }
      t.bt_references :subject, target_table: :better_together_people, null: true,
                                fk_options: { on_delete: :nullify },
                                index: { name: 'idx_bt_td_events_on_subject_id' }
      t.string :event_type, null: false
      t.string :domain, null: false
      t.string :role_identifier
      t.string :via
      t.jsonb  :details, null: false, default: {}
      t.index %i[platform_id event_type created_at], name: 'idx_bt_td_events_timeline'
    end
  end
end
