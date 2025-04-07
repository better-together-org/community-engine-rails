# frozen_string_literal: true

module BetterTogether
  # Access control for files
  class FilePolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present? && record.creator == agent
    end

    def update?
      user.present? && record.creator == agent
    end

    def create?
      user.present?
    end

    def download?
      (record.privacy_public? || record.creator == agent) && record.attached?
    end

    # Filtering and sorting for files according to permissions and context
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.with_creator(agent).order(created_at: :desc)
      end
    end
  end
end
