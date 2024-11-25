module BetterTogether
  module Categorizable
    extend ::ActiveSupport::Concern

    included do
      has_many :categorizations, class_name: 'BetterTogether::Categorization', as: :categorizable, dependent: :destroy
      has_many :categories, through: :categorizations
    end
  end
end
