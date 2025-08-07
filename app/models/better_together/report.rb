# frozen_string_literal: true

module BetterTogether
  # Record of a person reporting inappropriate content or users
  class Report < ApplicationRecord
    belongs_to :reporter, class_name: 'BetterTogether::Person'
    belongs_to :reportable, polymorphic: true

    validates :reason, presence: true
  end
end
