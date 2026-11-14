# frozen_string_literal: true

module BetterTogether
  # A person may read and change only their own stored cookie consent. The record is the Person.
  class CookieConsentPolicy < ApplicationPolicy
    def show? = own_record?
    def update? = own_record?

    private

    def own_record?
      agent.present? && record.is_a?(BetterTogether::Person) && record.id == agent.id
    end
  end
end
