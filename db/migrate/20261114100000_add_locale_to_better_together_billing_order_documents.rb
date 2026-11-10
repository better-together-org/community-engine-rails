# frozen_string_literal: true

# The language a stored invoice or receipt was written in. The order's language for documents can change after they were
# made (the buyer changes their own language), so the language of the PDF itself is kept on the document.
class AddLocaleToBetterTogetherBillingOrderDocuments < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_order_documents

  def up
    return unless table_exists?(TABLE)

    add_column TABLE, :locale, :string unless column_exists?(TABLE, :locale)
  end

  def down
    remove_column TABLE, :locale if table_exists?(TABLE) && column_exists?(TABLE, :locale)
  end
end
