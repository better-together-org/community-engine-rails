# frozen_string_literal: true

# Migrate Content::Css and Content::Html block `content` translations from
# mobility_string_translations (varchar) to mobility_text_translations (text).
#
# Background:
#   Both models previously declared `translates :content, type: :string`, which
#   routes Mobility to the `mobility_string_translations` table (character varying column).
#   They should use `type: :text` (mobility_text_translations, text column) since CSS
#   stylesheets and HTML content are not short strings.
#
#   On PostgreSQL, varchar without explicit limit is unlimited — no data loss occurs.
#   This migration moves existing rows to the correct table and is safe to re-run.
class MigrateCssHtmlBlockContentToTextTranslations < ActiveRecord::Migration[7.2]
  BLOCK_TYPES = %w[BetterTogether::Content::Css BetterTogether::Content::Html].freeze

  def up # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    # Fetch all string translations for these block types with key = 'content'
    rows = execute(<<~SQL).to_a
      SELECT id, translatable_type, translatable_id, key, value, locale, created_at, updated_at
      FROM mobility_string_translations
      WHERE key = 'content'
        AND translatable_type IN ('BetterTogether::Content::Css', 'BetterTogether::Content::Html')
    SQL

    return if rows.empty?

    say "Migrating #{rows.size} row(s) from mobility_string_translations → mobility_text_translations"

    rows.each do |row|
      # Insert into mobility_text_translations (upsert — skip if already present)
      execute(<<~SQL)
        INSERT INTO mobility_text_translations
          (translatable_type, translatable_id, key, value, locale, created_at, updated_at)
        VALUES (
          #{quote(row['translatable_type'])},
          #{quote(row['translatable_id'])}::uuid,
          #{quote(row['key'])},
          #{quote(row['value'])},
          #{quote(row['locale'])},
          #{quote(row['created_at'])},
          #{quote(row['updated_at'])}
        )
        ON CONFLICT (translatable_type, translatable_id, key, locale) DO UPDATE
          SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at
      SQL

      # Remove the old string translation row
      execute(<<~SQL)
        DELETE FROM mobility_string_translations WHERE id = #{row['id']}
      SQL
    end

    say "Migration complete."
  end

  def down # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    # Reverse: move text translations back to string translations
    rows = execute(<<~SQL).to_a
      SELECT id, translatable_type, translatable_id, key, value, locale, created_at, updated_at
      FROM mobility_text_translations
      WHERE key = 'content'
        AND translatable_type IN ('BetterTogether::Content::Css', 'BetterTogether::Content::Html')
    SQL

    return if rows.empty?

    say "Reverting #{rows.size} row(s) from mobility_text_translations → mobility_string_translations"

    rows.each do |row|
      execute(<<~SQL)
        INSERT INTO mobility_string_translations
          (translatable_type, translatable_id, key, value, locale, created_at, updated_at)
        VALUES (
          #{quote(row['translatable_type'])},
          #{quote(row['translatable_id'])}::uuid,
          #{quote(row['key'])},
          #{quote(row['value'])},
          #{quote(row['locale'])},
          #{quote(row['created_at'])},
          #{quote(row['updated_at'])}
        )
        ON CONFLICT (translatable_type, translatable_id, key, locale) DO UPDATE
          SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at
      SQL

      execute(<<~SQL)
        DELETE FROM mobility_text_translations WHERE id = #{row['id']}
      SQL
    end
  end
end
