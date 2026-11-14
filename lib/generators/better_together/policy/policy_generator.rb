# frozen_string_literal: true

require_relative '../namespace_options'

module BetterTogether
  module Generators
    # rails generate better_together:policy Project [--platform-record] [--namespace=X]
    class PolicyGenerator < Rails::Generators::NamedBase
      include NamespaceOptions

      source_root File.expand_path('templates', __dir__)

      class_option :platform_record, type: :boolean, default: true,
                                     desc: 'Inherit PlatformRecordPolicy (otherwise ApplicationPolicy)'

      def create_policy
        template 'policy.rb.tt', "app/policies/#{ns_path}#{file_name}_policy.rb"
      end

      def create_policy_spec
        template 'policy_spec.rb.tt', "spec/policies/#{ns_path}#{file_name}_policy_spec.rb"
      end

      private

      def parent_policy
        options[:platform_record] ? 'BetterTogether::PlatformRecordPolicy' : 'BetterTogether::ApplicationPolicy'
      end

      def policy_body # rubocop:disable Metrics/MethodLength
        namespaced_lines(<<~RUBY)
          # Authorization for #{class_name}. Tighten the rules before use.
          class #{class_name}Policy < #{parent_policy}
            def index?
              user.present?
            end

            def show?
              user.present?
            end

            def create?
              permitted_to?('manage_platform')
            end

            def update?
              permitted_to?('manage_platform')
            end

            def destroy?
              permitted_to?('manage_platform')
            end
          end
        RUBY
      end
    end
  end
end
