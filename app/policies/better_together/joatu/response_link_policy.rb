# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Governs access to ResponseLink records — explicit Offer↔Request pairings.
    #
    # NOTE: ResponseLinksController skips after_action :verify_authorized because
    # the create action redirects before Pundit's verification hook fires (which
    # would cause a DoubleRenderError). Call authorize explicitly in any new
    # controller actions added to that controller.
    class ResponseLinkPolicy < PlatformRecordPolicy
      def create? = user.present?
      alias new? create?

      def show?
        return false unless user.present?

        record.creator_id == agent&.id ||
          permitted_to?('manage_platform') ||
          permitted_to?('manage_platform_settings')
      end

      def destroy?
        return false unless user.present?

        permitted_to?('manage_platform') || permitted_to?('manage_platform_settings')
      end

      class Scope < PlatformRecordPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          return scope.none unless user.present?
          return platform_scoped if permitted_to?('manage_platform') || permitted_to?('manage_platform_settings')

          platform_scoped.where(creator_id: agent&.id)
        end
      end
    end
  end
end
