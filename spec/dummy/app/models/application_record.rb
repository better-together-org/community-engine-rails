# frozen_string_literal: true

# Real host apps define this (rails new generates it); Pay::ApplicationRecord inherits from it.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
