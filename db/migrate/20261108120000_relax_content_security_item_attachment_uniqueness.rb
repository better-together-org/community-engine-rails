# frozen_string_literal: true

# A content-security Item was unique per (attachable, attachment_name), which
# only fits has_one_attached. Scanning every ActiveStorage attachment needs one
# Item per blob for has_many_attached slots, so keep the lookup index but drop
# uniqueness. The (blob, attachable, attachment_name) index stays unique.
class RelaxContentSecurityItemAttachmentUniqueness < ActiveRecord::Migration[7.2]
  TABLE = :better_together_content_security_items
  INDEX = 'index_bt_content_security_items_on_attachment'
  COLUMNS = %i[attachable_type attachable_id attachment_name].freeze

  def up
    return unless table_exists?(TABLE)

    remove_index TABLE, name: INDEX if index_name_exists?(TABLE, INDEX)
    add_index TABLE, COLUMNS, name: INDEX unless index_name_exists?(TABLE, INDEX)
  end

  def down
    # Re-adding the unique index could fail on legitimate has_many data; leaving
    # the non-unique index in place is safe for older code.
  end
end
