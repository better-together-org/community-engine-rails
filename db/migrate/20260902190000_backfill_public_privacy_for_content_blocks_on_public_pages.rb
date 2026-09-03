# frozen_string_literal: true

# `BetterTogether::Content::Block` includes `Privacy`, whose column defaults to
# 'private'. Nothing syncs a block's privacy from the page it is placed on, and
# the page renderer does not filter blocks by privacy -- every block on a
# published public page is rendered in full to anonymous visitors.
#
# 0.11.0 added `BetterTogether::ActiveStorageSecurity#authorize_blob_access`
# (#1392), a fail-closed gate that only serves a blob to an anonymous request
# when its attachment record is `privacy_public?`. Pre-0.11.0 content blocks are
# 'private', so their background / hero images started returning 401 for
# anonymous visitors even though the block itself is on a public homepage --
# the exact regression already fixed for navigation items in
# 20251219191929_add_privacy_and_permissions_to_navigation_items.
#
# This backfills the same way: a visible block that lives on at least one
# published, public page is made 'public'. Raw SQL, so the
# `require_publishing_agreement_for_public_visibility` model callback (which
# needs a `Current.governed_agent` that does not exist at migration time) is not
# invoked -- the block is already publicly exposed via the page, this only
# aligns the column to that reality.
#
# Idempotent (only touches `privacy = 'private'` rows); a no-op on an instance
# whose public-page blocks are already public. `down` is a no-op -- restoring
# 'private' would re-break the images.
class BackfillPublicPrivacyForContentBlocksOnPublicPages < ActiveRecord::Migration[7.2]
  REQUIRED_COLUMNS = {
    better_together_content_blocks: %i[privacy visible],
    better_together_content_page_blocks: %i[block_id page_id],
    better_together_pages: %i[privacy published_at]
  }.freeze

  def up
    return unless schema_ready?

    result = execute(<<~SQL)
      UPDATE better_together_content_blocks cb
      SET    privacy = 'public', updated_at = NOW()
      WHERE  cb.privacy = 'private'
        AND  cb.visible = TRUE
        AND  EXISTS (
               SELECT 1
               FROM   better_together_content_page_blocks pb
               JOIN   better_together_pages p ON p.id = pb.page_id
               WHERE  pb.block_id = cb.id
                 AND  p.privacy = 'public'
                 AND  p.published_at IS NOT NULL
                 AND  p.published_at <= NOW()
             )
    SQL

    say "content blocks made public (visible, on a published public page): #{result.cmd_tuples}"
  end

  def down
    say 'BackfillPublicPrivacyForContentBlocksOnPublicPages is not reversible; ' \
        'restoring private would re-break anonymous access to their images.'
  end

  private

  def schema_ready?
    REQUIRED_COLUMNS.all? do |table, columns|
      table_exists?(table) && columns.all? { |column| column_exists?(table, column) }
    end
  end
end
