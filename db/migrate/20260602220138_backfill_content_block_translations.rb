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
      ::BetterTogether::Content::Block.where(type: block_type).find_each do |block|
        backfill_block_fields(block, fields, locale, ::BetterTogether::StringTranslation)
      end
    end
  end

  def backfill_text_fields(locale)
    TEXT_FIELDS.each do |block_type, fields|
      ::BetterTogether::Content::Block.where(type: block_type).find_each do |block|
        backfill_block_fields(block, fields, locale, ::BetterTogether::TextTranslation)
      end
    end
  end

  def backfill_block_fields(block, fields, locale, translation_class)
    data = block.read_attribute(:content_data) || {}
    fields.each do |field|
      value = data[field]
      next if value.blank?

      translation_class.find_or_create_by!(
        translatable_type: 'BetterTogether::Content::Block',
        translatable_id: block.id,
        key: field,
        locale: locale
      ) { |t| t.value = value }
    end
  end

  def down; end
end
