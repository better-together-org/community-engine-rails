# frozen_string_literal: true

module BetterTogether
  # Concern to make models invitable (able to have invitations sent to them)
  # Include this in any model that should support invitations
  module Invitable
    extend ActiveSupport::Concern

    included do
      has_many :invitations, as: :invitable, dependent: :destroy, class_name: 'BetterTogether::Invitation'

      BetterTogether::InvitationRegistry.register(self)
    end

    class_methods do
      # Override these methods to customize invitation behavior for this model type

      def invitation_class_name
        "#{module_parent.name}::#{name.demodulize}Invitation"
      end

      def invitation_class
        invitation_class_name.constantize
      rescue NameError
        BetterTogether::Invitation
      end

      def invitation_mailer_class_name
        "#{module_parent.name}::#{name.demodulize}InvitationsMailer"
      end

      def invitation_mailer_class
        invitation_mailer_class_name.constantize
      rescue NameError
        BetterTogether::InvitationMailerBase
      end

      def invitation_notifier_class_name
        "#{module_parent.name}::#{name.demodulize}InvitationNotifier"
      end

      def invitation_notifier_class
        invitation_notifier_class_name.constantize
      rescue NameError
        BetterTogether::InvitationNotifierBase
      end

      def invitation_policy_class_name
        "#{module_parent.name}::#{name.demodulize}InvitationPolicy"
      end

      def invitation_policy_class
        invitation_policy_class_name.constantize
      rescue NameError
        BetterTogether::InvitationPolicy
      end

      def invitation_table_body_id
        "#{name.demodulize.underscore}_invitations_table_body"
      end

      def invitation_partial_path
        'better_together/shared/invitation_row'
      end

      # Override to customize available people exclusions
      def invitation_additional_exclusions(invitable_instance, invited_ids)
        invited_ids
      end
    end

    # Instance methods for invitable models

    def invitation_url_param
      respond_to?(:slug) ? slug : to_param
    end

    def invitation_redirect_path
      if respond_to?(:path_for)
        path_for
      else
        Rails.application.routes.url_helpers.polymorphic_path(self)
      end
    end
  end
end
