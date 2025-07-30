# frozen_string_literal: true

# Creates posts table
class CreateBetterTogetherPosts < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :posts do |t|
      t.string 'type', default: 'BetterTogether::Post', null: false
      t.bt_identifier
      t.bt_protected
      t.bt_privacy
      t.bt_slug

      t.datetime :published_at,
                 index: {
                   name: 'by_post_publication_date'
                 }
    end
  end
end
