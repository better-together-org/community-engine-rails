# frozen_string_literal: true

class AddTypeToBetterTogetherCommunities < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    add_column :better_together_communities, :type, :string, null: false, default: 'BetterTogether::Community'
  end
end
