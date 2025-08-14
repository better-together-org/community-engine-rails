# frozen_string_literal: true

module BetterTogether
  class Categorization < ApplicationRecord # rubocop:todo Style/Documentation
    belongs_to :category
    belongs_to :categorizable, polymorphic: true, touch: true
  end
end
