# frozen_string_literal: true

class AddCreatorToBetterTogetherAuthorships < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    add_column :better_together_authorships, :creator_id, :uuid
    add_index :better_together_authorships, :creator_id, name: 'by_better_together_authorships_creator'
  end
end
