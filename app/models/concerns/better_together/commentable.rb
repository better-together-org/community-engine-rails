# frozen_string_literal: true

module BetterTogether
  # Concern for models that can receive BetterTogether::Comment records.
  module Commentable
    extend ActiveSupport::Concern

    included do
      has_many :comments, as: :commentable, class_name: 'BetterTogether::Comment', dependent: :destroy
    end
  end
end
