# frozen_string_literal: true

# Creates users table
class DeviseCreateBetterTogetherUsers < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
    create_bt_table :users do |t|
      ## Database authenticatable
      t.string :email, null: false, default: ''
      t.string :encrypted_password, null: false, default: ''

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      # Uncomment below if you wish to use trackable fields
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      # Uncomment below if you wish to use lockable fields
      t.integer  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      t.string   :unlock_token # Only if unlock strategy is :email or :both
      t.datetime :locked_at

      # Standard columns like lock_version and timestamps are added by create_bt_table

      # Additional indexes
      t.index :email, unique: true, name: 'index_better_together_users_on_email'
      t.index :reset_password_token, unique: true, name: 'index_better_together_users_on_reset_password_token'
      t.index :confirmation_token, unique: true, name: 'index_better_together_users_on_confirmation_token'
      # Uncomment below if you wish to add an index for unlock_token
      t.index :unlock_token, unique: true, name: 'index_better_together_users_on_unlock_token'
    end
  end
end
