# frozen_string_literal: true

# Creates posts table
class CreateBetterTogetherPosts < ActiveRecord::Migration[5.2]
  def change # rubocop:todo Metrics/MethodLength
    create_table :better_together_posts do |t|
      t.string :id

      t.datetime :published_at,
                 index: {
                   name: 'by_post_publication_date'
                 }

      t.string :post_privacy,
               index: {
                 name: 'by_post_privacy'
               },
               null: false,
               default: :public

      t.integer :lock_version, null: false, default: 0
      t.timestamps null: false
    end
  end
end
