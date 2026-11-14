# frozen_string_literal: true

module BetterTogether
  # Only managers of the target platform may view or change its trusted domains.
  class PlatformTrustedDomainPolicy < ApplicationPolicy
    %i[index? show? new? create? edit? update? destroy?].each do |action|
      define_method(action) { platform_manager_for_target_platform? }
    end

    private

    def platform_manager_for_target_platform?
      platform = record.respond_to?(:platform) ? record.platform : nil
      return false unless agent.present? && platform.present?

      agent.permitted_to?('manage_platform', platform) || agent.permitted_to?('manage_platform_settings', platform)
    end
  end
end
