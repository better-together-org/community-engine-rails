class AddNameAndDescriptionToPeople < ActiveRecord::Migration[6.0]
  def change
    add_column :better_together_people, :name, :string
    add_column :better_together_people, :description, :text
    remove_column :better_together_people, :given_name, :string
    remove_column :better_together_people, :family_name, :string
  end
end
