# frozen_string_literal: true

module BetterTogether
  module Content
    class BlockPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
      def index?
        platform_content_manager?
      end

      def show?
        platform_content_manager?
      end

      def create?
        platform_content_manager?
      end

      def new?
        create?
      end

      def update?
        platform_content_manager?
      end

      def edit?
        update?
      end

      def destroy?
        platform_content_manager?
      end

      def preview_markdown?
        user.present?
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          scope.includes(:pages).order('created_at DESC').all
        end
      end

      private

      def platform_content_manager?
        user.present? && (permitted_to?('manage_platform_settings') || permitted_to?('manage_platform'))
      end
    end
  end
end
