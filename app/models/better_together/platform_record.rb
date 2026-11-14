# frozen_string_literal: true

module BetterTogether
  # Abstract base class for all ActiveRecord models scoped to a platform.
  # Inheriting from this class establishes the belongs_to :platform association,
  # the before_validation assignment callback, and the :for_platform scope
  # defined in BetterTogether::PlatformScoped.
  class PlatformRecord < ApplicationRecord
    self.abstract_class = true

    include PlatformScoped
  end
end
