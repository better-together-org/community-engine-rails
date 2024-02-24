# frozen_string_literal: true

class CreateBetterTogetherJwtDenylists < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :jwt_denylists, pk_index_prefix: 'jwt_denylist' do |t|
      # Additional columns specific to JWT Denylist
      t.string :jti
      t.datetime :exp

      # Standard columns like lock_version and timestamps are added by create_bt_table

      # Adding index on jti
      t.index :jti, name: 'index_better_together_jwt_denylists_on_jti'
    end
  end
end
