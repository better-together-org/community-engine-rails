# frozen_string_literal: true

module BetterTogether
  # Renders the platform-owned content blocks that fill named layout slots.
  module PlatformContentSlotsHelper
    include BetterTogether::Content::BlocksHelper

    MAX_HEADLINES = 20
    MAX_HEADLINE_LENGTH = 140

    # Renders the slot's block for the given platform (default: the request's platform).
    # Fragment cached per platform, slot, locale and block version. Never raises: a broken
    # slot renders nothing so the page around it still loads.
    def render_platform_content_slot(slot, platform: host_platform) # rubocop:disable Metrics/AbcSize
      block = renderable_content_slot_block(platform, slot)
      return if block.nil?

      key = ['platform-content-slot', platform.id, slot.to_s, I18n.locale, block.cache_key_with_version]
      capture do
        cache(key) do
          concat(content_tag(:div, content_slot_body(block), id: "platform-slot-#{slot.to_s.dasherize}",
                                                             class: "platform-content-slot platform-content-slot--#{slot.to_s.dasherize}",
                                                             data: { platform_content_slot: slot.to_s }))
        end
      end
    rescue StandardError => e
      Rails.logger.warn("[PlatformContentSlots] #{slot} skipped: #{e.class}: #{e.message}")
      nil
    end

    # One random headline from the 404 headlines slot (one per line), or nil.
    def platform_not_found_headline(platform: host_platform) # rubocop:disable Metrics/AbcSize
      block = renderable_content_slot_block(platform, :not_found_headlines)
      return if block.nil?

      Nokogiri::HTML5.fragment(block.content.to_s).text.lines
                     .filter_map { |line| line.strip.truncate(MAX_HEADLINE_LENGTH).presence }
                     .first(MAX_HEADLINES).sample
    rescue StandardError => e
      Rails.logger.warn("[PlatformContentSlots] headlines skipped: #{e.class}: #{e.message}")
      nil
    end

    private

    # A slot block is shown only when it is the right type for the slot, visible and non-empty.
    def renderable_content_slot_block(platform, slot) # rubocop:disable Metrics/CyclomaticComplexity
      return unless platform&.persisted?

      block = platform.content_slot_block(slot)
      return unless block&.visible?
      return unless BetterTogether::PlatformContentSlots::SLOTS.dig(slot.to_sym, :types)&.include?(block.type)

      block if content_slot_text(block).present?
    end

    def content_slot_text(block)
      case block
      when BetterTogether::Content::RichText then block.content&.body&.to_html.to_s.strip
      when BetterTogether::Content::Html then block.content.to_s.strip
      when BetterTogether::Content::Markdown then block.markdown_source.to_s.strip
      end
    end

    def content_slot_body(block)
      case block
      when BetterTogether::Content::RichText then block.content
      when BetterTogether::Content::Html then sanitize_block_html(block.content)
      when BetterTogether::Content::Markdown then content_tag(:div, block.rendered_html, class: 'markdown-content')
      end
    end
  end
end
