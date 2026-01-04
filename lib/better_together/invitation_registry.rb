# frozen_string_literal: true

module BetterTogether
  # Registry for managing different invitation types and their configurations
  class InvitationRegistry
    class << self
      def registry
        @registry ||= {}
      end

      def register(invitable_class)
        key = invitable_class.name.demodulize.underscore.to_sym
        registry[key] = InvitationTypeConfig.new(invitable_class)
      end

      def config_for(invitable_class_or_name)
        key = case invitable_class_or_name
              when Class
                invitable_class_or_name.name.demodulize.underscore.to_sym
              when String, Symbol
                invitable_class_or_name.to_s.underscore.to_sym
              else
                invitable_class_or_name.class.name.demodulize.underscore.to_sym
              end

        registry[key] || raise(ArgumentError, "No invitation configuration found for #{key}")
      end

      def config_for_model_name(model_name)
        key = model_name.underscore.to_sym
        registry[key] || raise(ArgumentError, "No invitation configuration found for #{key}")
      end

      def registered_types
        registry.keys
      end

      def clear!
        @registry = {}
      end
    end

    # Configuration object for a specific invitation type
    class InvitationTypeConfig
      attr_reader :invitable_class

      def initialize(invitable_class)
        @invitable_class = invitable_class
      end

      def invitation_class
        invitable_class.invitation_class
      end

      def mailer_class
        invitable_class.invitation_mailer_class
      end

      def notifier_class
        invitable_class.invitation_notifier_class
      end

      def policy_class
        invitable_class.invitation_policy_class
      end

      def table_body_id
        invitable_class.invitation_table_body_id
      end

      def partial_path
        invitable_class.invitation_partial_path
      end

      def additional_exclusions(invitable_instance, invited_ids)
        invitable_class.invitation_additional_exclusions(invitable_instance, invited_ids)
      end

      def model_name
        invitable_class.name.demodulize.underscore
      end

      def param_key
        "#{model_name}_id"
      end

      def route_key
        model_name.pluralize
      end
    end
  end
end
