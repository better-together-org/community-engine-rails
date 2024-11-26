# frozen_string_literal: true

class SetPeopleCommunityNullFalse < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def change
    change_column_null :better_together_people, :community_id, false
  end
end
