# frozen_string_literal: true

# Gives every page whose hero block has a background image a feature image pointing at the same
# blob, so link previews and the banner no longer depend on the hero block. No file is copied and
# the hero block is untouched. Pages that already have a feature image are skipped.
#
# Dry run: DRY_RUN=1 bin/rails db:migrate only reports how many pages would change.
# Reversible: `down` removes only feature image attachments that share a blob with the page's hero.
class CopyHeroBackgroundsToPageFeatureImage < ActiveRecord::Migration[7.2]
  # Lowest-position hero block per page that has a background image attached.
  HERO_SOURCES_SQL = <<~SQL.squish
    SELECT DISTINCT ON (pb.page_id) pb.page_id, att.blob_id
    FROM better_together_content_page_blocks pb
    JOIN better_together_content_blocks b ON b.id = pb.block_id AND b.type = 'BetterTogether::Content::Hero'
    JOIN active_storage_attachments att ON att.record_id = b.id AND att.name = 'background_image_file'
    ORDER BY pb.page_id, pb.position
  SQL

  def up
    return unless tables_present?

    rows = select_rows(<<~SQL.squish)
      SELECT src.page_id, src.blob_id FROM (#{HERO_SOURCES_SQL}) src
      WHERE NOT EXISTS (
        SELECT 1 FROM active_storage_attachments f
        WHERE f.record_id = src.page_id AND f.name = 'feature_image'
      )
    SQL
    say "#{rows.size} page(s) would receive a feature image from their hero block"
    return if ENV['DRY_RUN'].present?

    rows.each { |page_id, blob_id| insert_feature_image(page_id, blob_id) }
  end

  def down
    return unless tables_present?

    execute <<~SQL.squish
      DELETE FROM active_storage_attachments f
      USING (#{HERO_SOURCES_SQL}) src
      WHERE f.record_id = src.page_id AND f.name = 'feature_image' AND f.blob_id = src.blob_id
    SQL
  end

  private

  def tables_present?
    %i[better_together_pages better_together_content_page_blocks better_together_content_blocks
       active_storage_attachments].all? { |table| table_exists?(table) }
  end

  def insert_feature_image(page_id, blob_id)
    execute <<~SQL.squish
      INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
      SELECT 'feature_image', 'BetterTogether::Page', #{quote(page_id)}::uuid, #{quote(blob_id)}::uuid, NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM active_storage_attachments
        WHERE record_id = #{quote(page_id)}::uuid AND name = 'feature_image'
      )
    SQL
  end
end
