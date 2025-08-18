# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Offer represents a service or item someone is willing to provide
    class Offer < ApplicationRecord
      include Creatable
      include Exchange
      include Metrics::Viewable

      has_many :requests, class_name: 'BetterTogether::Joatu::Request', through: :agreements

      categorizable class_name: '::BetterTogether::Joatu::Category'
    end
  end
end
