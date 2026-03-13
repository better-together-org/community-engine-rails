# frozen_string_literal: true

module BetterTogether
  # CSS block management methods for Platform.
  module PlatformCssBlockManagement
    extend ActiveSupport::Concern

    def css_block
      @css_block ||= blocks.find_by(type: 'BetterTogether::Content::Css')
    end

    def css_block?
      css_block.present?
    end

    def css_block_attributes=(attrs = {})
      @css_block = nil
      new_attrs = attrs.except(:type).merge(protected: true, privacy: 'public')
      block = blocks.find_by(type: 'BetterTogether::Content::Css')
      if block
        block.update!(new_attrs)
        @css_block = block
      else
        new_block = BetterTogether::Content::Css.new(new_attrs)
        platform_blocks.build(block: new_block)
        @css_block = new_block
      end
    end
  end
end
