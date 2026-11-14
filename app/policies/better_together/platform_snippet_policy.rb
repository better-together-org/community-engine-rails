# frozen_string_literal: true

module BetterTogether
  # Snippets run code in visitors' browsers, so every action needs manage_platform_code on the
  # snippet's own platform. manage_platform and manage_platform_settings are deliberately not enough.
  class PlatformSnippetPolicy < ApplicationPolicy
    def index? = code_manager?
    def new? = code_manager?
    def create? = code_manager?
    def edit? = code_manager?
    def update? = code_manager?
    def destroy? = code_manager?
    def move? = code_manager?
    def toggle_all? = code_manager?

    # Adding an origin to the platform CSP is a security change on top of a code change.
    def allow_origin?
      code_manager? && agent.permitted_to?('manage_platform_security', target_platform)
    end

    # Safe mode may be requested by anyone who could fix the broken snippet.
    def safe_mode?
      code_manager?
    end

    private

    def target_platform
      record.respond_to?(:platform) ? record.platform : nil
    end

    def code_manager?
      agent.present? && target_platform.present? && agent.permitted_to?('manage_platform_code', target_platform)
    end
  end
end
