# frozen_string_literal: true

# Beneficiary opt-in gate for the generalized sponsorship system — mirrors
# allow_membership_requests (a plain boolean + predicate, not a scope).
class AddAcceptsSponsorshipToBetterTogetherPeople < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_people, :accepts_sponsorship)

    add_column :better_together_people, :accepts_sponsorship, :boolean, default: false, null: false
  end
end
