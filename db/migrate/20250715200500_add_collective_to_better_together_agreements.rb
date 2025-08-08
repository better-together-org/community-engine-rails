# frozen_string_literal: true

# Adds collective flag to agreements
class AddCollectiveToBetterTogetherAgreements < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_agreements, :collective, :boolean, default: false, null: false
  end
end
