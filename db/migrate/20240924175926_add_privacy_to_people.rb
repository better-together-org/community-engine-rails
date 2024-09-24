class AddPrivacyToPeople < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_people do |t|
      t.bt_privacy
    end
  end
end
