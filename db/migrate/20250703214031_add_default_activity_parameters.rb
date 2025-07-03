# frozen_string_literal: true

class AddDefaultActivityParameters < ActiveRecord::Migration[7.1]
  def change
    change_column_default :better_together_activities, :parameters, from: nil, to: '{}'
  end
end
