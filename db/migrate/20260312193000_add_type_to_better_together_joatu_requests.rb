# frozen_string_literal: true

class AddTypeToBetterTogetherJoatuRequests < ActiveRecord::Migration[7.2]
  def up
    add_column :better_together_joatu_requests, :type, :string, null: false, default: 'BetterTogether::Joatu::Request'
    add_index :better_together_joatu_requests, :type
  end

  def down
    remove_index :better_together_joatu_requests, :type
    remove_column :better_together_joatu_requests, :type
  end
end
