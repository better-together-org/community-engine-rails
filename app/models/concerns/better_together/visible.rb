# frozen_string_literal: true

module BetterTogether
  module Visible # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      validates :visible, inclusion: { in: [true, false] }

      scope :visible, -> { where(visible: true) }
    end

    def visible?
      visible
    end
  end
end
