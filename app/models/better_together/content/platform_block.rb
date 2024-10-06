class BetterTogether::Content::PlatformBlock < ApplicationRecord
  belongs_to :platform, class_name: 'BetterTogether::Platform', touch: true
  belongs_to :block, class_name: 'BetterTogether::Content::Block', autosave: true

  accepts_nested_attributes_for :block
end
