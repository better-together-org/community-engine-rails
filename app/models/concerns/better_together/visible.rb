# frozen_string_literal: true

module BetterTogether
  module Visible
    extend ActiveSupport::Concern

    included do
      validates :visible, inclusion: { in: [true, false] }

      scope :visible, -> { where(visible: true) }
    end
  end
end
