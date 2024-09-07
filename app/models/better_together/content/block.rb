# frozen_string_literal: true
require 'storext'

module BetterTogether
  module Content
    class Block < ApplicationRecord
      include Translatable

      include ::Storext.model

      has_many :page_blocks, dependent: :destroy
      has_many :pages, through: :page_blocks

      store_attributes :accessibility_attributes do
        aria_label String, default: ''
        aria_hidden Boolean, default: false
        aria_describedby String, default: ''
        aria_live String, default: 'polite'  # 'polite' or 'assertive'
        aria_role String, default: ''
        aria_controls String, default: ''
        aria_expanded Boolean, default: false
        aria_tabindex Integer, default: 0
      end

      store_attributes :content_settings do
        # Add content-specific settings here
      end

      store_attributes :data_attributes do
        data_controller String, default: ''
        data_action String, default: ''
        data_target String, default: ''
      end

      store_attributes :html_attributes do
        # Add HTML attributes here
      end

      store_attributes :layout_settings do
        # Add layout-related settings here
      end

      store_attributes :media_settings do
        # Add media-related settings here
      end

      store_attributes :style_settings do
        css_classes String, default: ''
        css_styles String, default: ''
      end
    end
  end
end
