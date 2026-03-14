# frozen_string_literal: true

module BetterTogether
  # CSS block management methods for Platform.
  module PlatformCssBlockManagement
    extend ActiveSupport::Concern

    included do
      after_save :persist_pending_css_block
    end

    def css_block
      @css_block ||= blocks.find_by(type: 'BetterTogether::Content::Css')
    end

    def css_block?
      css_block.present?
    end

    def css_block_attributes=(attrs = {})
      @css_block = nil
      @pending_css_block_attrs = nil
      new_attrs = attrs.except(:type).merge(protected: true, privacy: 'public')
      block = blocks.find_by(type: 'BetterTogether::Content::Css')
      if block
        block.update!(new_attrs)
        @css_block = block
      else
        @pending_css_block_attrs = new_attrs
        @css_block = BetterTogether::Content::Css.new(new_attrs)
      end
    end

    private

    def persist_pending_css_block
      return unless @pending_css_block_attrs

      attrs = @pending_css_block_attrs
      @pending_css_block_attrs = nil
      new_block = BetterTogether::Content::Css.create!(attrs)
      platform_blocks.create!(block: new_block)
      @css_block = new_block
    end
  end
end
