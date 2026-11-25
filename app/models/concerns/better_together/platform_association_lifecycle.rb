# frozen_string_literal: true

module BetterTogether
  # Status transitions for PlatformAssociation. The managed side drives them (the policy decides who);
  # revoked is terminal. Derived edges stop being effective on their own because effectiveness is computed.
  module PlatformAssociationLifecycle
    extend ActiveSupport::Concern

    included do
      validate :status_transition_allowed, on: :update
    end

    def accept!(by:, scopes: nil)
      require_status!(:requested)
      self.granted_scopes = narrowed(scopes) if scopes
      self.accepted_by = by
      self.accepted_at = Time.current
      transition!(:active, by, 'accepted')
    end

    def narrow!(scopes, by:)
      require_status!(:requested, :active, :suspended)
      self.granted_scopes = narrowed(scopes)
      stamp(by)
      save!
      audit('narrowed', actor_id: by&.id, scopes: granted_scopes)
    end

    def suspend!(by:)
      require_status!(:active)
      transition!(:suspended, by, 'suspended')
    end

    def resume!(by:)
      require_status!(:suspended)
      transition!(:active, by, 'resumed')
    end

    def revoke!(by:)
      require_status!(:requested, :active, :suspended)
      transition!(:revoked, by, 'revoked')
    end

    private

    def narrowed(scopes)
      wanted = Array(scopes).map(&:to_s).uniq
      raise ArgumentError, 'scopes may only be narrowed' if (wanted - granted_scopes).any?

      wanted
    end

    def require_status!(*allowed)
      return if allowed.any? { |name| status.to_s == name.to_s }

      raise ArgumentError, "cannot change a #{status} platform association"
    end

    def stamp(by)
      self.status_changed_by = by
      self.status_changed_at = Time.current
    end

    def transition!(new_status, by, event)
      self.status = new_status
      stamp(by)
      save!
      audit(event, actor_id: by&.id, scopes: granted_scopes)
      self
    end

    def status_transition_allowed
      errors.add(:status, :invalid) if status_changed? && status_was == 'revoked'
    end
  end
end
