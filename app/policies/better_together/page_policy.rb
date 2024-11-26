# frozen_string_literal: true

# app/policies/better_together/role_policy.rb

module BetterTogether
  class PagePolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      (record.published? && record.privacy_public?) || user.present?
    end

    def create?
      permitted_to?('manage_platform')
    end

    def new?
      create?
    end

    def update?
      permitted_to?('manage_platform')
    end

    def edit?
      update?
    end

    def destroy?
      permitted_to?('manage_platform') && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        base_scope = scope.includes(
          :string_translations,
          blocks: { background_image_file_attachment: :blob }
        )
        if permitted_to?('manage_platform')
          base_scope.order(:identifier)
        else
          base_scope.published
        end
      end
    end
  end
end
