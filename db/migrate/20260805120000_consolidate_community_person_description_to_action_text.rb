# frozen_string_literal: true

# Community and Person previously had TWO separate description-type attributes:
# a plain `description` (used by PrimaryCommunity's auto-bootstrap, the JSON:API
# CommunityResource, structured data, wizards, OAuth bio linking, Devise
# registration) and a rich-text `description_html` (used by their own real
# Trix-editor edit forms). Both models now use a single rich-text `description`
# (matching PrimaryCommunity's change) — `description_html` is retired.
#
# This migrates existing data in two passes:
#  1. Move any remaining plain-text `description` (mobility_text_translations)
#     for Community into action_text_rich_texts under name='description'
#     (Person's plain description was already migrated by the prior
#     20260805110000 migration, since Person includes PrimaryCommunity).
#  2. For both models, any existing `description_html` row (already
#     action_text_rich_texts) is renamed to `description` — overwriting
#     whatever step 1 produced, since description_html holds real user-entered
#     content from the actual working edit form, while the plain description
#     was often just PrimaryCommunity's bootstrap fallback text.
#
# Down is best-effort, not a perfect mirror: consolidating two sources into one
# is inherently lossy about which parts came from which original attribute.
class ConsolidateCommunityPersonDescriptionToActionText < ActiveRecord::Migration[7.2]
  MODEL_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze

  def up
    migrate_plain_community_description_to_action_text
    consolidate_description_html_into_description
  end

  def down # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    types_sql = MODEL_TYPES.map { |t| quote(t) }.join(', ')

    rows = execute(<<~SQL).to_a
      SELECT id, record_type, record_id, body, locale, created_at, updated_at
      FROM action_text_rich_texts
      WHERE name = 'description' AND record_type IN (#{types_sql})
    SQL

    return if rows.empty?

    say "Reverting #{rows.size} description row(s) back to description_html"

    rows.each do |row|
      execute(<<~SQL)
        INSERT INTO action_text_rich_texts
          (name, body, record_type, record_id, locale, created_at, updated_at)
        VALUES (
          'description_html',
          #{quote(row['body'])},
          #{quote(row['record_type'])},
          #{quote(row['record_id'])}::uuid,
          #{quote(row['locale'])},
          #{quote(row['created_at'])},
          #{quote(row['updated_at'])}
        )
        ON CONFLICT (record_type, record_id, name, locale) DO UPDATE
          SET body = EXCLUDED.body, updated_at = EXCLUDED.updated_at
      SQL
    end
  end

  private

  def migrate_plain_community_description_to_action_text # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    rows = execute(<<~SQL).to_a
      SELECT id, translatable_type, translatable_id, value, locale, created_at, updated_at
      FROM mobility_text_translations
      WHERE key = 'description' AND translatable_type = 'BetterTogether::Community'
    SQL

    return if rows.empty?

    say "Migrating #{rows.size} plain Community description row(s) to action_text_rich_texts"

    rows.each do |row|
      body = row['value'].present? ? ERB::Util.html_escape(row['value']) : row['value']

      execute(<<~SQL)
        INSERT INTO action_text_rich_texts
          (name, body, record_type, record_id, locale, created_at, updated_at)
        VALUES (
          'description',
          #{quote(body)},
          #{quote(row['translatable_type'])},
          #{quote(row['translatable_id'])}::uuid,
          #{quote(row['locale'])},
          #{quote(row['created_at'])},
          #{quote(row['updated_at'])}
        )
        ON CONFLICT (record_type, record_id, name, locale) DO UPDATE
          SET body = EXCLUDED.body, updated_at = EXCLUDED.updated_at
      SQL

      execute(<<~SQL)
        DELETE FROM mobility_text_translations WHERE id = #{row['id']}
      SQL
    end
  end

  def consolidate_description_html_into_description # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    types_sql = MODEL_TYPES.map { |t| quote(t) }.join(', ')

    rows = execute(<<~SQL).to_a
      SELECT id, record_type, record_id, body, locale, created_at, updated_at
      FROM action_text_rich_texts
      WHERE name = 'description_html' AND record_type IN (#{types_sql})
    SQL

    return if rows.empty?

    say "Consolidating #{rows.size} description_html row(s) into description"

    rows.each do |row|
      execute(<<~SQL)
        INSERT INTO action_text_rich_texts
          (name, body, record_type, record_id, locale, created_at, updated_at)
        VALUES (
          'description',
          #{quote(row['body'])},
          #{quote(row['record_type'])},
          #{quote(row['record_id'])}::uuid,
          #{quote(row['locale'])},
          #{quote(row['created_at'])},
          #{quote(row['updated_at'])}
        )
        ON CONFLICT (record_type, record_id, name, locale) DO UPDATE
          SET body = EXCLUDED.body, updated_at = EXCLUDED.updated_at
      SQL

      execute(<<~SQL)
        DELETE FROM action_text_rich_texts WHERE id = #{quote(row['id'])}::uuid
      SQL
    end
  end
end
