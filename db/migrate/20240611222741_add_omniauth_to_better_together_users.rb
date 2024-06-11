class AddOmniauthToBetterTogetherUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_users, :provider, :string
    add_column :better_together_users, :uid, :string
  end
end
