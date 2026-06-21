# frozen_string_literal: true

class CreateBetterTogetherRobots < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_robots)
      create_bt_table :robots do |t|
        t.bt_references :platform, null: true
        t.string :name, null: false
        t.string :identifier, null: false
        t.string :robot_type, null: false, default: 'translation'
        t.string :provider, null: false, default: 'openai'
        t.string :default_model
        t.string :default_embedding_model
        t.text :system_prompt
        t.json :settings, null: false, default: {}
        t.boolean :active, null: false, default: true

        t.index :robot_type
        t.index :provider
        t.index :active
      end
    end

    unless index_exists?(
      :better_together_robots,
      %i[platform_id identifier],
      unique: true,
      name: 'index_bt_robots_on_platform_and_identifier'
    )
      add_index :better_together_robots,
                %i[platform_id identifier],
                unique: true,
                name: 'index_bt_robots_on_platform_and_identifier'
    end

    return if index_exists?(
      :better_together_robots,
      :identifier,
      unique: true,
      name: 'index_bt_global_robots_on_identifier'
    )

    add_index :better_together_robots,
              :identifier,
              unique: true,
              where: 'platform_id IS NULL',
              name: 'index_bt_global_robots_on_identifier'
  end
end
