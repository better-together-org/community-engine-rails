# frozen_string_literal: true

# Which agreements a buyer must accept before paying, and the evidence that they did. Final
# state; guarded so a re-run is a no-op.
#
# * A requirement ties an agreement to a target: empty means the platform's default for every
#   purchase; a seller (community or person) or a plan narrows it to theirs. It can be limited
#   to one purpose (subscription, one-time, ticket, exchange) and/or one payment method (for
#   the terms that come with cash, a cheque or an e-transfer). `mode` says whether it adds to the
#   default terms or replaces them.
# * An acceptance records, per order, which agreement the signer accepted, as it read then
#   (identifier, title, content digest). The agreement can change or be re-accepted later;
#   this row is the evidence of what applied to this purchase. The order is tied by a composite
#   foreign key so the evidence is always on the order's own platform.
class CreateBetterTogetherBillingAgreementRequirements < ActiveRecord::Migration[7.2]
  def up
    create_requirements
    create_acceptances
  end

  def down
    %i[better_together_billing_order_agreement_acceptances better_together_billing_agreement_requirements]
      .each { |table| drop_table table if table_exists?(table) }
  end

  private

  def create_requirements
    return if table_exists?(:better_together_billing_agreement_requirements)

    create_bt_table :billing_agreement_requirements do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_agr_req_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.references :agreement, null: false, type: :uuid, index: { name: 'idx_bt_billing_agr_req_agreement' },
                               foreign_key: { to_table: :better_together_agreements }
      t.string :target_type
      t.uuid :target_id
      t.string :purpose
      t.string :payment_method
      t.string :mode, null: false, default: 'additional'
      t.integer :position, null: false, default: 0
    end

    add_index :better_together_billing_agreement_requirements, %i[target_type target_id], name: 'idx_bt_billing_agr_req_target'
  end

  def create_acceptances # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_order_agreement_acceptances)

    create_bt_table :billing_order_agreement_acceptances do |t|
      t.uuid :platform_id, null: false
      t.uuid :order_id, null: false
      t.references :agreement, null: false, type: :uuid, index: { name: 'idx_bt_billing_order_acc_agreement' },
                               foreign_key: { to_table: :better_together_agreements }
      t.references :signer, null: false, type: :uuid, index: { name: 'idx_bt_billing_order_acc_signer' },
                            foreign_key: { to_table: :better_together_people }
      t.string :on_behalf_of_type
      t.uuid :on_behalf_of_id
      t.string :agreement_identifier, null: false
      t.string :agreement_title, null: false
      t.string :agreement_content_digest, null: false
      t.string :acceptance_method, null: false
      t.datetime :accepted_at, null: false
    end

    add_index :better_together_billing_order_agreement_acceptances, :platform_id, name: 'idx_bt_billing_order_acc_platform'
    add_index :better_together_billing_order_agreement_acceptances, %i[order_id agreement_id], unique: true,
                                                                                               name: 'idx_bt_billing_order_acc_unique'
    add_foreign_key :better_together_billing_order_agreement_acceptances, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_order_agreement_acceptances, :better_together_billing_orders,
                    column: %i[order_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_order_acc_order_platform'
  end
end
