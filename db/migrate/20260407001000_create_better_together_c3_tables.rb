# frozen_string_literal: true

# C3 Community Contribution Token tables.
# C3 is the exchange unit for the Community Action Network — compute contributions,
# volunteer time, skills, code reviews, and moderation actions all earn C3,
# which is exchangeable peer-to-peer via the Joatu system.
class CreateBetterTogetherC3Tables < ActiveRecord::Migration[7.2]
  def change
    # C3 exchange rates — contribution_type → C3 per unit
    unless table_exists?(:better_together_c3_exchange_rates)
      create_bt_table :c3_exchange_rates do |t|
        t.integer :contribution_type, null: false # enum index: compute_cpu, compute_gpu, ...
        t.string :contribution_type_name, null: false
        t.decimal :rate, precision: 18, scale: 6, null: false # C3 per unit
        t.string :unit_name, null: false        # cpu_hour, gpu_hour, video_minute, etc.
        t.string :unit_label, null: false       # human-readable label
        t.string :source_system, default: 'borgberry'
        t.boolean :active, default: true, null: false
      end

      add_index :better_together_c3_exchange_rates, :contribution_type,
                unique: true,
                where: 'active = true',
                name: 'idx_bt_c3_exchange_rates_active_type'
    end

    # C3 tokens — one record per earned contribution event
    unless table_exists?(:better_together_c3_tokens)
      create_bt_table :c3_tokens do |t|
        # Earner — Person or future AgentActor
        t.references :earner, polymorphic: true, type: :uuid, null: false,
                              index: { name: 'idx_bt_c3_tokens_earner' }

        t.references :community, type: :uuid, null: true,
                                 foreign_key: { to_table: :better_together_communities, on_delete: :nullify },
                                 index: { name: 'idx_bt_c3_tokens_community' }

        # Contribution metadata
        t.integer :contribution_type, null: false # enum: compute_cpu=0, compute_gpu=1, ...
        t.string :contribution_type_name, null: false

        # Amount in millitokens (1 C3 = 10_000 millitokens) for integer arithmetic
        t.bigint :c3_millitokens, null: false, default: 0

        # Source evidence
        t.string :source_ref, null: false # job_id, PR number, CE event ID
        t.string :source_system, null: false, default: 'borgberry'

        # Contribution details
        t.decimal :units, precision: 18, scale: 6 # units contributed (e.g. video minutes)
        t.decimal :duration_s, precision: 12, scale: 3
        t.jsonb :metadata, null: false, default: {}

        # Lifecycle
        t.string :status, null: false, default: 'pending' # pending, confirmed, disputed, settled
        t.datetime :emitted_at
        t.datetime :confirmed_at
      end

      add_index :better_together_c3_tokens, :source_ref,
                name: 'idx_bt_c3_tokens_source_ref'
      add_index :better_together_c3_tokens, :status,
                name: 'idx_bt_c3_tokens_status'
      add_index :better_together_c3_tokens, :contribution_type,
                name: 'idx_bt_c3_tokens_contribution_type'
    end

    # C3 balances — running totals per holder
    return if table_exists?(:better_together_c3_balances)

    create_bt_table :c3_balances do |t|
      t.references :holder, polymorphic: true, type: :uuid, null: false,
                            index: { name: 'idx_bt_c3_balances_holder' }

      t.references :community, type: :uuid, null: true,
                               foreign_key: { to_table: :better_together_communities, on_delete: :nullify },
                               index: { name: 'idx_bt_c3_balances_community' }

      t.bigint :available_millitokens, null: false, default: 0
      t.bigint :locked_millitokens, null: false, default: 0 # reserved for in-flight exchanges
      t.bigint :lifetime_earned_millitokens, null: false, default: 0
    end

    add_index :better_together_c3_balances, %i[holder_type holder_id community_id],
              unique: true, name: 'idx_bt_c3_balances_holder_community'
  end
end
