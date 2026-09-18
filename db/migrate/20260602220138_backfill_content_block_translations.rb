# frozen_string_literal: true

class BackfillContentBlockTranslations < ActiveRecord::Migration[7.2]
  STRING_FIELDS = {
    'BetterTogether::Content::AlertBlock' => %w[heading],
    'BetterTogether::Content::CallToActionBlock' => %w[heading subheading primary_button_label secondary_button_label primary_button_url
                                                       secondary_button_url],
    'BetterTogether::Content::IframeBlock' => %w[iframe_url],
    'BetterTogether::Content::Image' => %w[attribution_url],
    'BetterTogether::Content::Hero' => %w[cta_url],
    'BetterTogether::Content::QuoteBlock' => %w[attribution_name attribution_title attribution_organization],
    'BetterTogether::Content::AccordionBlock' => %w[heading],
    'BetterTogether::Content::StatisticsBlock' => %w[heading],
    'BetterTogether::Content::VideoBlock' => %w[caption],
    'BetterTogether::Content::CommunitiesBlock' => %w[view_more_url],
    'BetterTogether::Content::EventsBlock' => %w[view_more_url],
    'BetterTogether::Content::PeopleBlock' => %w[view_more_url],
    'BetterTogether::Content::PostsBlock' => %w[view_more_url],
    'BetterTogether::Content::ChecklistBlock' => %w[view_more_url],
    'BetterTogether::Content::NavigationAreaBlock' => %w[view_more_url]
  }.freeze

  TEXT_FIELDS = {
    'BetterTogether::Content::AlertBlock' => %w[body_text],
    'BetterTogether::Content::CallToActionBlock' => %w[body_text],
    'BetterTogether::Content::QuoteBlock' => %w[quote_text],
    'BetterTogether::Content::AccordionBlock' => %w[accordion_items_json],
    'BetterTogether::Content::StatisticsBlock' => %w[stats_json]
  }.freeze

  def up
    locale = 'en'

    backfill_string_fields(locale)
    backfill_text_fields(locale)
  end

  private

  def backfill_string_fields(locale)
    STRING_FIELDS.each do |block_type, fields|
      blocks = ActiveRecord::Base.connection.execute(
        "SELECT id, content_data FROM #{quote_table_name('better_together_content_blocks')} WHERE type = '#{block_type}'"
      )

      blocks.each do |row|
        block_id = row['id']
        raw = row['content_data']
        content_data = raw.is_a?(Hash) ? raw : JSON.parse(raw || '{}')

        fields.each do |field|
          value = content_data[field]
          next if value.blank?

          insert_translation('mobility_string_translations', block_id, field, value, locale)
        end
      end
    end
  end

  def backfill_text_fields(locale)
    TEXT_FIELDS.each do |block_type, fields|
      blocks = ActiveRecord::Base.connection.execute(
        "SELECT id, content_data FROM #{quote_table_name('better_together_content_blocks')} WHERE type = '#{block_type}'"
      )

      blocks.each do |row|
        block_id = row['id']
        raw = row['content_data']
        content_data = raw.is_a?(Hash) ? raw : JSON.parse(raw || '{}')

        fields.each do |field|
          value = content_data[field]
          next if value.blank?

          insert_translation('mobility_text_translations', block_id, field, value, locale)
        end
      end
    end
  end

  def insert_translation(table_name, translatable_id, key, value, locale)
    conn = ActiveRecord::Base.connection
    translatable_type = 'BetterTogether::Content::Block'

    existing = conn.execute(
      "SELECT id FROM #{quote_table_name(table_name)} " \
      "WHERE translatable_type = '#{translatable_type}' " \
      "AND translatable_id = '#{translatable_id}' " \
      "AND key = '#{key}' " \
      "AND locale = '#{locale}' " \
      "LIMIT 1"
    )

    return if existing.any?

    conn.execute(
      "INSERT INTO #{quote_table_name(table_name)} " \
      "(locale, key, value, translatable_type, translatable_id, created_at, updated_at) " \
      "VALUES ('#{locale}', '#{key}', #{conn.quote(value)}, " \
      "'#{translatable_type}', '#{translatable_id}', NOW(), NOW())"
    )
  end

  def down; end
end
