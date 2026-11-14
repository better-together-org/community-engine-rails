# frozen_string_literal: true

# Migrate `description` translations for PrimaryCommunity includers that were still
# governed by PrimaryCommunity's own plain-text declaration (Country, Platform, State,
# Continent, Region, Person) from mobility_text_translations (plain :text backend) to
# action_text_rich_texts (Mobility's :action_text backend), matching PrimaryCommunity's
# updated `translates :description, backend: :action_text` declaration.
#
# Building/Floor/Room/Settlement already used the action_text backend for description
# before this change (via their own now-removed redundant `translates` redeclaration),
# so their rows already live in action_text_rich_texts and are untouched here.
#
# ActionText::Serialization#dump stores a RichText's body as a plain HTML string
# (content.to_html) — no special encoding. Existing plain-text values are HTML-escaped
# before insertion so they round-trip back to their original plain text when rendered
# as HTML (an unescaped '<'/'&' in the source text would otherwise be misparsed as
# markup by Nokogiri when the rich text is next rendered).
class MigratePrimaryCommunityDescriptionToActionText < ActiveRecord::Migration[7.2]
  MODEL_TYPES = %w[
    BetterTogether::Geography::Country
    BetterTogether::Platform
    BetterTogether::Geography::State
    BetterTogether::Geography::Continent
    BetterTogether::Geography::Region
    BetterTogether::Person
  ].freeze

  def up # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    types_sql = MODEL_TYPES.map { |t| quote(t) }.join(', ')

    rows = execute(<<~SQL).to_a
      SELECT id, translatable_type, translatable_id, value, locale, created_at, updated_at
      FROM mobility_text_translations
      WHERE key = 'description' AND translatable_type IN (#{types_sql})
    SQL

    return if rows.empty?

    say "Migrating #{rows.size} description row(s) from mobility_text_translations -> action_text_rich_texts"

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

    say 'Migration complete.'
  end

  def down # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    types_sql = MODEL_TYPES.map { |t| quote(t) }.join(', ')

    rows = execute(<<~SQL).to_a
      SELECT id, record_type, record_id, body, locale, created_at, updated_at
      FROM action_text_rich_texts
      WHERE name = 'description' AND record_type IN (#{types_sql})
    SQL

    return if rows.empty?

    say "Reverting #{rows.size} description row(s) from action_text_rich_texts -> mobility_text_translations"

    rows.each do |row|
      value = row['body'].present? ? CGI.unescapeHTML(row['body']) : row['body']

      execute(<<~SQL)
        INSERT INTO mobility_text_translations
          (translatable_type, translatable_id, key, value, locale, created_at, updated_at)
        VALUES (
          #{quote(row['record_type'])},
          #{quote(row['record_id'])}::uuid,
          'description',
          #{quote(value)},
          #{quote(row['locale'])},
          #{quote(row['created_at'])},
          #{quote(row['updated_at'])}
        )
        ON CONFLICT (translatable_id, translatable_type, locale, key) DO UPDATE
          SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at
      SQL

      execute(<<~SQL)
        DELETE FROM action_text_rich_texts WHERE id = #{quote(row['id'])}::uuid
      SQL
    end
  end
end
