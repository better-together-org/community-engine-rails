# frozen_string_literal: true

module BetterTogether
  module Billing
    # Abstract base for Community Engine's own billing models (events, plans, ...).
    #
    # Inside `module Billing`, `ApplicationRecord` resolves to this class rather than
    # BetterTogether::ApplicationRecord, so billing models pick it up by writing
    # `class Plan < ApplicationRecord` like every other model.
    #
    # It deliberately does NOT include Seedable: that concern adds
    # `export_as_seed`, which would let a billing record, with its decrypted
    # payment data, be written into a seed. It also skips BetterTogetherId; the
    # tables use the database's own uuid default.
    #
    # It does take the small parts of BetterTogether::ApplicationRecord that translated attributes rely on:
    # `extra_permitted_attributes` (Translatable calls `super` into it), a locale-prefixed `cache_key` (so a cached
    # fragment of translated text never serves one language to another) and a `to_s` that reads the record's name.
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
      self.implicit_order_column = :created_at

      def self.extra_permitted_attributes = []

      def cache_key = "#{I18n.locale}/#{super}"

      def to_s
        %i[name title identifier slug label].each do |attribute|
          return public_send(attribute) if respond_to?(attribute) && public_send(attribute).present?
        end

        super
      end
    end
  end
end
