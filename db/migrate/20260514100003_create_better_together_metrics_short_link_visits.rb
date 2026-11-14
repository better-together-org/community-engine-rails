# frozen_string_literal: true

class CreateBetterTogetherMetricsShortLinkVisits < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_metrics_short_link_visits)

    create_bt_table :short_link_visits, prefix: 'better_together_metrics' do |t|
      t.references :short_link, null: false, type: :uuid,
                                foreign_key: { to_table: :better_together_short_links },
                                index: { name: 'index_bt_metrics_short_link_visits_on_short_link_id' }

      t.string  :referrer,           limit: 2048
      t.string  :user_agent_string,  limit: 255
      t.string  :remote_addr,        limit: 45 # anonymized; /24 IPv4 or /48 IPv6

      t.datetime :visited_at, null: false

      t.boolean :logged_in,     null: false, default: false
      t.boolean :potential_bot, null: false, default: false

      t.references :platform, null: false, type: :uuid,
                              foreign_key: { to_table: :better_together_platforms },
                              index: { name: 'index_bt_metrics_short_link_visits_on_platform_id' }
    end
  end
end
