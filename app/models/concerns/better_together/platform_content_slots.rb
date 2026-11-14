# frozen_string_literal: true

module BetterTogether
  # Platform-owned content blocks in named layout slots (header above, footer above, 404 message
  # and 404 headlines). Each slot is an ordinary Content::Block with a reserved identifier,
  # found by platform_id so two platforms never see each other's slot content.
  module PlatformContentSlots
    extend ActiveSupport::Concern

    RICH_TEXT = 'BetterTogether::Content::RichText'
    HTML = 'BetterTogether::Content::Html'
    MARKDOWN = 'BetterTogether::Content::Markdown'
    CONTENT_TYPES = [RICH_TEXT, HTML, MARKDOWN].freeze

    SLOTS = {
      header_above: { identifier: 'slot-header-above', types: CONTENT_TYPES },
      footer_above: { identifier: 'slot-footer-above', types: CONTENT_TYPES },
      not_found_message: { identifier: 'slot-error-404', types: CONTENT_TYPES },
      not_found_headlines: { identifier: 'slot-error-404-headlines', types: [HTML].freeze }
    }.freeze

    # Per-language character ceiling for a slot block's content.
    MAX_CONTENT_LENGTH = 20_000
    # Attributes that must never come from a form: the platform decides them.
    FORCED_ATTRIBUTES = %w[id type identifier privacy visible protected platform_id platform creator_id remove
                           markdown_file_path auto_sync_from_file markdown_source_type active_source].freeze

    # Permitted nested parameters, one entry per slot, for the platform controller.
    def self.permitted_attributes
      allowed = CONTENT_TYPES.map(&:constantize)
      content_keys = allowed.flat_map { |klass| klass.localized_attribute_list + klass.extra_permitted_attributes }
      content_keys = content_keys.map(&:to_sym) - FORCED_ATTRIBUTES.map(&:to_sym)
      keys = (%i[type remove] + content_keys).uniq
      [{ content_slot_blocks_attributes: SLOTS.keys.index_with { keys } }]
    end

    def self.default_type(slot)
      SLOTS.fetch(slot.to_sym)[:types].first
    end

    included do
      validate :content_slot_blocks_valid
      after_save :persist_content_slot_blocks
    end

    # The slot's block for this platform, or nil. Lookup is always scoped by platform_id.
    def content_slot_block(slot)
      identifier = SLOTS.dig(slot.to_sym, :identifier)
      return unless identifier && persisted?

      content_slot_blocks_index[identifier]
    end

    # Accepts { header_above: { content_en: '...', remove: '1' }, ... }
    def content_slot_blocks_attributes=(attrs)
      @content_slot_attrs = {}
      @content_slot_plan = nil
      attrs.to_h.each do |slot, slot_attrs|
        next unless SLOTS.key?(slot.to_sym) && slot_attrs.respond_to?(:to_h)

        @content_slot_attrs[slot.to_sym] = slot_attrs.to_h.with_indifferent_access
      end
    end

    private

    def content_slot_blocks_index
      @content_slot_blocks_index ||= BetterTogether::Content::Block
                                     .where(platform_id: id, identifier: SLOTS.values.pluck(:identifier))
                                     .index_by(&:identifier)
    end

    def content_slot_blocks_valid
      return if @content_slot_attrs.blank?

      @content_slot_plan = @content_slot_attrs.filter_map { |slot, attrs| plan_content_slot(slot, attrs) }
    end

    def plan_content_slot(slot, attrs) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      existing = content_slot_block(slot)
      return { slot:, action: :destroy, block: existing } if ActiveModel::Type::Boolean.new.cast(attrs[:remove])

      type = attrs[:type].presence || existing&.type || PlatformContentSlots.default_type(slot)
      return slot_error(slot, :invalid_type) unless SLOTS[slot][:types].include?(type)
      return slot_error(slot, :too_long) if content_too_long?(attrs)

      block = build_content_slot_block(slot, type, existing, attrs)
      return if block.nil?

      block.valid? || block.errors.full_messages.each { |msg| errors.add(:content_slot_blocks, "#{slot}: #{msg}") }
      { slot:, action: :save, block: }
    end

    def build_content_slot_block(slot, type, existing, attrs)
      content = attrs.except(*FORCED_ATTRIBUTES)
      return if existing.nil? && content.values.all?(&:blank?)

      block = existing || type.constantize.new(platform: self, identifier: SLOTS[slot][:identifier])
      # Slot content is as visible as the platform itself, never more open than its privacy ceiling.
      block.assign_attributes(content.merge(privacy:, protected: true, visible: true))
      block
    end

    def content_too_long?(attrs)
      attrs.except(*FORCED_ATTRIBUTES).values.any? { |value| value.is_a?(String) && value.length > MAX_CONTENT_LENGTH }
    end

    def slot_error(slot, key)
      errors.add(:content_slot_blocks, I18n.t("better_together.platforms.content_slots.errors.#{key}",
                                              slot: I18n.t("better_together.platforms.content_slots.#{slot}.label"),
                                              max: MAX_CONTENT_LENGTH))
      nil
    end

    def persist_content_slot_blocks
      plan = @content_slot_plan
      return if plan.blank?

      @content_slot_plan = @content_slot_attrs = @content_slot_blocks_index = nil
      plan.each do |entry|
        entry[:action] == :destroy ? destroy_content_slot_block(entry[:block]) : save_content_slot_block(entry[:block])
      end
    end

    def save_content_slot_block(block)
      block.save!
      platform_blocks.find_or_create_by!(block:)
    end

    def destroy_content_slot_block(block)
      return unless block

      BetterTogether::Content::PlatformBlock.where(block_id: block.id).delete_all
      block.update!(protected: false)
      block.destroy!
    end
  end
end
