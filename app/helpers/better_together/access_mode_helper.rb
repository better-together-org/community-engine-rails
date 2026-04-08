# frozen_string_literal: true

module BetterTogether
  # Shared presentation helpers for explaining how a resource can be joined.
  module AccessModeHelper
    def access_mode_label(resource)
      case resource.access_mode.to_sym
      when :invitation
        t('better_together.access_modes.labels.invitation', default: 'Invitation only')
      when :request
        t('better_together.access_modes.labels.request', default: 'Request to join')
      else
        t('better_together.access_modes.labels.open', default: 'Open join')
      end
    end

    def access_mode_description(resource)
      case resource.access_mode.to_sym
      when :invitation
        invitation_access_mode_description(resource)
      when :request
        t('better_together.access_modes.descriptions.generic.request',
          default: 'People can ask to join. A coordinator reviews requests before access is granted.')
      else
        open_access_mode_description(resource)
      end
    end

    def access_mode_badge_class(resource)
      case resource.access_mode.to_sym
      when :invitation
        'text-bg-warning'
      when :request
        'text-bg-info'
      else
        'text-bg-success'
      end
    end

    private

    def invitation_access_mode_description(resource)
      if resource.is_a?(BetterTogether::Platform)
        return t('better_together.access_modes.descriptions.platform.invitation',
                 default: 'People need an invitation before they can create an account here.')
      end

      t('better_together.access_modes.descriptions.generic.invitation',
        default: 'People need an invitation before they can join this space.')
    end

    def open_access_mode_description(resource)
      if resource.is_a?(BetterTogether::Platform)
        return t('better_together.access_modes.descriptions.platform.open',
                 default: 'People can create an account and join without waiting for approval.')
      end

      t('better_together.access_modes.descriptions.generic.open',
        default: 'People can join right away without waiting for approval.')
    end
  end
end
