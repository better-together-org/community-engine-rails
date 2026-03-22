# frozen_string_literal: true

module BetterTogether
  module Users
    class ConfirmationsController < ::Devise::ConfirmationsController # rubocop:todo Style/Documentation
      include DeviseLocales

      skip_before_action :check_platform_privacy

      protected

      # Override Devise's confirm method to activate memberships after confirmation
      def confirm_account
        resource = resource_class.confirm_by_token(params[resource_name][:confirmation_token])

        if resource.errors.empty?
          activate_pending_memberships(resource)
        end

        resource
      end

      def after_confirmation_path_for(resource_name, resource)
        activate_pending_memberships(resource) if resource.persisted?
        super
      end

      private

      def activate_pending_memberships(user)
        return unless user&.person

        # Activate all pending memberships for this person
        user.person.person_community_memberships.pending.find_each(&:activate!)
        user.person.person_platform_memberships.pending.find_each(&:activate!)
      end
    end
  end
end
