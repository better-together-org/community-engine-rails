# frozen_string_literal: true

# `BetterTogether::ActiveStorageSecurity#publicly_accessible?` (added for #1392) fails closed:
# any attachment whose owning record doesn't respond to `privacy_public?` (and isn't a
# `Content::Block`) always 401s for anonymous visitors, regardless of whether the record is
# actually public. `Geography::Settlement`, `Category`, and the rest of the geography taxonomy
# chain never included `Privacy`, so their `cover_image` attachments (and, for Settlement,
# any future description/media) 401 for anon users -- the `/g/settlements/*` cover-image
# regression this migration fixes, plus the same gap on `Category#cover_image`.
#
# Default is 'public' (not `bt_privacy`'s own 'private' default): these are admin/seed-managed
# reference and taxonomy records with no privacy UI, not user-authored content -- their existing
# behavior everywhere else in the app is "always visible", so a 'private' default would silently
# flip that behavior for every existing row. Using `default: 'public'` also means Postgres
# backfills every existing row at `ADD COLUMN` time -- no separate backfill migration needed,
# unlike 20260902190000 (Content::Block defaults to 'private' by design, since blocks are
# editor-authored and opt-in to visibility).
class AddPrivacyToGeographyAndCategoryTables < ActiveRecord::Migration[7.2]
  TABLES = %w[
    better_together_geography_settlements
    better_together_categories
    better_together_geography_continents
    better_together_geography_countries
    better_together_geography_regions
    better_together_geography_states
  ].freeze

  def change
    TABLES.each do |table_name|
      next unless table_exists?(table_name)
      next if column_exists?(table_name, :privacy)

      change_table table_name do |t|
        t.bt_privacy(table_name, default: 'public')
      end
    end
  end
end
