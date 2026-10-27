# frozen_string_literal: true

module BetterTogether
  # Shared behaviour for host-app Community subtypes (STI on the type column). A subtype stays a Community to routes,
  # forms and policies, uses the community role set, and can have roles and permissions scoped to it: including this
  # registers it as a Resourceful resource type. Override community_subtype_label to name its role tab.
  module CommunitySubtype
    extend ActiveSupport::Concern

    included do
      BetterTogether::Resourceful.register_resource_class(
        name, label: -> { BetterTogether::SafeClassResolver.resolve(name, allowed: [name])&.community_subtype_label }
      )

      # Invitation-token authorization finds a policy by class name, so each subtype gets a named one.
      namespace = name.deconstantize.presence&.constantize || Object
      policy_name = "#{name.demodulize}Policy"
      namespace.const_set(policy_name, Class.new(BetterTogether::CommunityPolicy)) unless
        namespace.const_defined?(policy_name, false)
    end

    class_methods do
      def model_name
        BetterTogether::Community.model_name
      end

      def policy_class
        BetterTogether::CommunityPolicy
      end

      def community_subtype_label
        I18n.t("better_together.community_subtypes.#{name.demodulize.underscore}", default: name.demodulize.titleize)
      end
    end

    def default_member_role
      BetterTogether::Role.find_by(resource_type: self.class.base_class.name, identifier: default_member_role_identifier)
    end
  end
end
