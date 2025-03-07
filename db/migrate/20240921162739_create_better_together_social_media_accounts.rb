# frozen_string_literal: true

class CreateBetterTogetherSocialMediaAccounts < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    create_bt_table :social_media_accounts do |t|
      t.string :platform, null: false
      t.string :handle, null: false
      t.string :url
      t.bt_privacy('better_together_social_media_accounts', default: 'public')
      t.bt_references :contact_detail, null: false, foreign_key: { to_table: :better_together_contact_details }
    end

    add_index :better_together_social_media_accounts, %i[contact_detail_id platform], unique: true,
                                                                                      # rubocop:todo Layout/LineLength
                                                                                      name: 'index_bt_sma_on_contact_detail_and_platform'
    # rubocop:enable Layout/LineLength
  end
end
