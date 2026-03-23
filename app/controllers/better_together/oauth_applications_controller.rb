# frozen_string_literal: true

module BetterTogether
  # Web UI controller for managing OAuth applications.
  # Platform managers can manage all applications; owners can manage their own.
  # Available under the host dashboard.
  class OauthApplicationsController < ResourceController
    protected

    def resource_class
      ::BetterTogether::OauthApplication
    end

    def resource_collection
      policy_scope(resource_class).order(created_at: :desc)
    end

    # Auto-assign the current user's person as the application owner on create
    def resource_instance(attrs = {})
      @resource ||= resource_class.new(attrs)
      @resource.owner ||= current_user.person if current_user&.person
      instance_variable_set("@#{resource_name}", @resource)
    end
  end
end
