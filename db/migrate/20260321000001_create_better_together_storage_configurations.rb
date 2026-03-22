# frozen_string_literal: true

# Creates storage_configurations table and adds active storage config FK to platforms.
#
# Each platform can have many storage configurations; platforms.storage_configuration_id
# identifies the platform's currently active (primary) storage backend.
# rubocop:disable Metrics/MethodLength
class CreateBetterTogetherStorageConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :storage_configurations do |t|
      t.bt_references :platform, null: false

      # Human-readable label for this configuration (e.g. "Primary S3", "Local dev")
      t.string :name, null: false

      # One of: local, amazon, s3_compatible
      t.string :service_type, null: false, default: 'local'

      # S3 / S3-compatible fields (null for local)
      t.string :endpoint # Required for s3_compatible; nil for amazon
      t.string :bucket
      t.string :region

      # Credentials encrypted via ActiveRecord::Encryption
      t.string :access_key_id
      t.string :secret_access_key

      t.index :service_type
      t.index :platform_id
    end

    # Add nullable FK on platforms pointing to the active storage configuration.
    # Deferred constraint avoids chicken-and-egg issue when creating platform + config together.
    add_reference :better_together_platforms,
                  :storage_configuration,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_storage_configurations, deferrable: :deferred }
  end
end
# rubocop:enable Metrics/MethodLength
