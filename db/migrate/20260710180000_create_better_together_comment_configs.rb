# frozen_string_literal: true

class CreateBetterTogetherCommentConfigs < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_comment_configs)

    create_bt_table :comment_configs do |t|
      t.bt_references :commentable,
                      polymorphic: true,
                      null: false,
                      index: { name: 'bt_comment_configs_on_commentable', unique: true }

      # Who can post new comments: inherit (default, today's behavior) | community | disabled
      t.string :permission, null: false, default: 'inherit'
      # Who can see the comment thread: inherit (default, today's behavior) | community
      t.string :visibility, null: false, default: 'inherit'
    end
  end
end
