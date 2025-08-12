# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Authorization for Joatu requests
    class RequestPolicy < ApplicationPolicy
      def index?
        user.present?
      end

      def show?
        user.present?
      end

      def create?
        user.present?
      end

      def update?
        user.present?
      end

      def destroy?
        user.present?
      end

      class Scope < ApplicationPolicy::Scope
      end
    end
  end
end
