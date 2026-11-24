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

      # Confirming an address proves the address, not approval. Memberships that wait on a steward
      # (community requests, elevated roles) stay pending; only the baseline rows activate here.
      def activate_pending_memberships(user)
        return unless user&.person

        user.person.person_platform_memberships.pending.joins(:role)
            .where(better_together_roles: { identifier: 'platform_member' }).find_each(&:activate!)

        user.person.person_community_memberships.pending.includes(:joinable).find_each do |membership|
          next if community_awaits_approval?(membership.joinable)

          membership.activate!
        end
      end

      def community_awaits_approval?(community)
        platform = community&.primary_platform
        platform.present? && platform.membership_requests_enabled_for?(community)
      end
    end
  end
end
