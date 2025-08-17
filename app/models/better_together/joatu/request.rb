# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request represents a need someone wants fulfilled
    class Request < ApplicationRecord
      include Exchange
      include Creatable

      has_many :offers, class_name: 'BetterTogether::Joatu::Offer', through: :agreements

      categorizable class_name: '::BetterTogether::Joatu::Category'
    end
  end
end
