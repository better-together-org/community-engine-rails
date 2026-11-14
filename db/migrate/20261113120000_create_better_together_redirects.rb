# frozen_string_literal: true

# Platform-scoped URL redirects (301/302/307/308) and gone (410) responses, resolved before routing.
class CreateBetterTogetherRedirects < ActiveRecord::Migration[7.2]
  TABLE = :better_together_redirects
  PATH_INDEX = 'index_bt_redirects_on_platform_and_lower_from_path'

  def up
    unless table_exists?(TABLE)
      create_bt_table :redirects do |t|
        t.bt_references :platform, null: false, target_table: :better_together_platforms,
                                   index: { name: 'index_bt_redirects_on_platform_id' }
        t.string   :from_path, null: false
        t.text     :to_path
        t.integer  :status,         null: false, default: 301
        t.boolean  :active,         null: false, default: true
        t.boolean  :preserve_query, null: false, default: true
        t.string   :source,         null: false, default: 'manual'
        t.text     :note
        t.integer  :hit_count, null: false, default: 0
        t.datetime :last_hit_at
      end
    end

    return if index_name_exists?(TABLE, PATH_INDEX)

    add_index TABLE, 'platform_id, lower(from_path)', unique: true, name: PATH_INDEX
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end
end
