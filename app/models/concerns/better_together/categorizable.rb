# frozen_string_literal: true

module BetterTogether
  module Categorizable # rubocop:todo Style/Documentation
    extend ::ActiveSupport::Concern

    included do
      has_many :categorizations, class_name: 'BetterTogether::Categorization', as: :categorizable, dependent: :destroy
      has_many :categories, through: :categorizations
    end
  end
end
