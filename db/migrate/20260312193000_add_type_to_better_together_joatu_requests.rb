# frozen_string_literal: true

class AddTypeToBetterTogetherJoatuRequests < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:better_together_joatu_requests, :type)
      add_column :better_together_joatu_requests, :type, :string, null: false, default: 'BetterTogether::Joatu::Request'
    end
    return if index_name_exists?(:better_together_joatu_requests, 'index_better_together_joatu_requests_on_type')

    add_index :better_together_joatu_requests, :type
  end

  def down
    remove_index :better_together_joatu_requests, :type if index_name_exists?(:better_together_joatu_requests,
                                                                              'index_better_together_joatu_requests_on_type')
    remove_column :better_together_joatu_requests, :type if column_exists?(:better_together_joatu_requests, :type)
  end
end
