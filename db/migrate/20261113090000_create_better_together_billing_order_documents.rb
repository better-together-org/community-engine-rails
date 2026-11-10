# frozen_string_literal: true

# The invoice or receipt PDF of an order, kept as an Upload so it can be fetched from storage instead of being
# generated again. One row per generated document; the current one of each kind has no `superseded_at`. The
# order is tied by a composite foreign key, so a document is always on its order's own platform.
class CreateBetterTogetherBillingOrderDocuments < ActiveRecord::Migration[7.2]
  def up # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_order_documents)

    create_bt_table :billing_order_documents do |t|
      t.uuid :platform_id, null: false
      t.uuid :order_id, null: false
      t.references :upload, null: false, type: :uuid, index: { name: 'idx_bt_billing_order_docs_upload', unique: true },
                            foreign_key: { to_table: :better_together_uploads }
      t.string :kind, null: false
      t.string :fingerprint, null: false
      t.string :time_zone, null: false
      t.datetime :generated_at, null: false
      t.datetime :superseded_at
    end

    add_index :better_together_billing_order_documents, :platform_id, name: 'idx_bt_billing_order_docs_platform'
    add_index :better_together_billing_order_documents, %i[order_id kind], unique: true, where: 'superseded_at IS NULL',
                                                                           name: 'idx_bt_billing_order_docs_current'
    add_foreign_key :better_together_billing_order_documents, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_order_documents, :better_together_billing_orders,
                    column: %i[order_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_order_docs_order_platform'
  end

  def down
    drop_table :better_together_billing_order_documents if table_exists?(:better_together_billing_order_documents)
  end
end
