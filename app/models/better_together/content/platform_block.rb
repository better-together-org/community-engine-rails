# frozen_string_literal: true

module BetterTogether
  module Content
    class PlatformBlock < ApplicationRecord # rubocop:todo Style/Documentation
      belongs_to :platform, class_name: 'BetterTogether::Platform', touch: true
      belongs_to :block, class_name: 'BetterTogether::Content::Block', autosave: true

      accepts_nested_attributes_for :block
    end
  end
end
