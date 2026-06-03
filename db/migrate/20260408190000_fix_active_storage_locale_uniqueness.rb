# frozen_string_literal: true

class FixActiveStorageLocaleUniqueness < ActiveRecord::Migration[7.2]
  def up
    remove_index :active_storage_attachments, name: :index_active_storage_attachments_on_record_and_name_and_locale if
      index_exists?(:active_storage_attachments,
                    %i[record_type record_id name locale],
                    name: :index_active_storage_attachments_on_record_and_name_and_locale)

    remove_index :active_storage_attachments, name: :index_active_storage_attachments_uniqueness if
      index_exists?(:active_storage_attachments,
                    %i[record_type record_id name blob_id],
                    name: :index_active_storage_attachments_uniqueness)

    return if index_exists?(:active_storage_attachments,
                            %i[record_type record_id name blob_id locale],
                            name: :index_active_storage_attachments_uniqueness)

    add_index :active_storage_attachments,
              %i[record_type record_id name blob_id locale],
              unique: true,
              name: :index_active_storage_attachments_uniqueness
  end

  def down
    remove_index :active_storage_attachments, name: :index_active_storage_attachments_uniqueness if
      index_exists?(:active_storage_attachments, name: :index_active_storage_attachments_uniqueness)

    unless index_exists?(:active_storage_attachments,
                         %i[record_type record_id name blob_id],
                         name: :index_active_storage_attachments_uniqueness)
      add_index :active_storage_attachments,
                %i[record_type record_id name blob_id],
                unique: true,
                name: :index_active_storage_attachments_uniqueness
    end

    unless index_exists?(:active_storage_attachments,
                         %i[record_type record_id name locale],
                         name: :index_active_storage_attachments_on_record_and_name_and_locale)
      add_index :active_storage_attachments,
                %i[record_type record_id name locale],
                unique: true,
                name: :index_active_storage_attachments_on_record_and_name_and_locale
    end
  end
end
