# frozen_string_literal: true

# Adds a locale column to Active Storage attachments to support per-locale attachments.
# This migration is intentionally explicit and kept readable rather than split into
# many tiny helper methods.
class AddLocaleToActiveStorageAttachments < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/MethodLength
  def up
    # Step 1: add nullable column so deploy can be staged
    add_column :active_storage_attachments, :locale, :string, default: I18n.default_locale.to_s

    # Step 2: backfill existing rows to default locale in one SQL update
    say_with_time("Backfilling active_storage_attachments.locale to default locale") do
      default = I18n.default_locale.to_s
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE active_storage_attachments
        SET locale = #{ActiveRecord::Base.connection.quote(default)}
        WHERE locale IS NULL
      SQL
    end

    # Step 3: make column not null
    change_column_null :active_storage_attachments, :locale, false, I18n.default_locale.to_s

    # Step 4: replace the stock uniqueness index with a locale-aware variant that
    # still allows multiple blobs per Action Text rich text.
    remove_index :active_storage_attachments, name: :index_active_storage_attachments_uniqueness if
      index_exists?(:active_storage_attachments,
                    %i[record_type record_id name blob_id],
                    name: :index_active_storage_attachments_uniqueness)

    unless index_exists?(:active_storage_attachments,
                         %i[record_type record_id name blob_id locale],
                         name: :index_active_storage_attachments_uniqueness)
      add_index :active_storage_attachments,
                %i[record_type record_id name blob_id locale],
                unique: true,
                name: :index_active_storage_attachments_uniqueness
    end
  end

  # rubocop:enable Metrics/MethodLength

  def down
    remove_index :active_storage_attachments, name: :index_active_storage_attachments_uniqueness if
      index_exists?(:active_storage_attachments,
                    %i[record_type record_id name blob_id locale],
                    name: :index_active_storage_attachments_uniqueness)

    unless index_exists?(:active_storage_attachments,
                         %i[record_type record_id name blob_id],
                         name: :index_active_storage_attachments_uniqueness)
      add_index :active_storage_attachments,
                %i[record_type record_id name blob_id],
                unique: true,
                name: :index_active_storage_attachments_uniqueness
    end

    remove_column :active_storage_attachments, :locale if column_exists?(:active_storage_attachments, :locale)
  end
end
