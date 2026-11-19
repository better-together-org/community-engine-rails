# frozen_string_literal: true

module BetterTogether
  # Redirects are managed per platform by that platform's managers.
  class RedirectPolicy < ApplicationPolicy
    %i[index? new? create? edit? update? destroy? new_import? create_import?].each do |action|
      define_method(action) { platform_manager_for_target_platform? }
    end

    private

    def target_platform
      record.respond_to?(:platform) ? record.platform : nil
    end

    def platform_manager_for_target_platform?
      return false unless agent.present? && target_platform.present?

      agent.permitted_to?('manage_platform', target_platform) ||
        agent.permitted_to?('manage_platform_settings', target_platform)
    end
  end
end
