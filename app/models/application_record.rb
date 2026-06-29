# frozen_string_literal: true

# Shared Active Record base class for engine and dependency models.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
