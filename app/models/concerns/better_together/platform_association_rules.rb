# frozen_string_literal: true

module BetterTogether
  # Validation rules for PlatformAssociation: platform types, locality, graph shape (no cycles, bounded depth)
  # and delegation (a derived edge can only narrow what its parent edge holds).
  module PlatformAssociationRules
    extend ActiveSupport::Concern

    OPERATOR_TYPE = 'BetterTogether::OperatorPlatform'
    MANAGEABLE_TYPES = %w[BetterTogether::HostedPlatform BetterTogether::OperatorPlatform].freeze

    class_methods do
      # Ids reachable from a platform following non-revoked edges: :down to managed, :up to operators.
      def reachable_ids(platform_id, direction)
        from, to = direction == :down ? %i[operator_platform_id managed_platform_id] : %i[managed_platform_id operator_platform_id]
        seen = []
        queue = [platform_id]
        while (current = queue.shift)
          next_ids = authority.where.not(status: 'revoked').where(from => current).pluck(to) - seen
          seen.concat(next_ids)
          queue.concat(next_ids)
        end
        seen
      end

      def chain_length(platform_id, direction, trail = [])
        return 0 if trail.include?(platform_id)

        from, to = direction == :down ? %i[operator_platform_id managed_platform_id] : %i[managed_platform_id operator_platform_id]
        ids = authority.where.not(status: 'revoked').where(from => platform_id).distinct.pluck(to)
        ids.map { |id| 1 + chain_length(id, direction, trail + [platform_id]) }.max || 0
      end
    end

    private

    def scopes_known
      unknown = Array(granted_scopes) - BetterTogether::PlatformAssociation::SCOPES
      errors.add(:granted_scopes, :inclusion) if unknown.any?
    end

    def platform_types_allowed
      errors.add(:operator_platform, :invalid) if operator_platform && operator_platform.type != OPERATOR_TYPE
      errors.add(:managed_platform, :invalid) if managed_platform && MANAGEABLE_TYPES.exclude?(managed_platform.type)
    end

    def platforms_differ
      errors.add(:managed_platform_id, :invalid) if operator_platform_id.present? && operator_platform_id == managed_platform_id
    end

    def transport_matches_locality
      return unless operator_platform && managed_platform

      remote = operator_platform.remote? || managed_platform.remote?
      errors.add(:transport, :invalid) if remote == transport_direct?
    end

    def endpoints_immutable
      return unless operator_platform_id_changed? || managed_platform_id_changed? || delegated_from_id_changed?

      errors.add(:base, :immutable_endpoints)
    end

    def expiry_in_future
      errors.add(:expires_at, :invalid) if expires_at.present? && expires_at <= Time.current
    end

    def acceptable_graph
      return unless graph_checkable?

      if downstream_of_managed?
        errors.add(:managed_platform_id, :cycle)
      elsif chain_depth > BetterTogether::PlatformAssociation::MAX_DEPTH
        errors.add(:base, :too_deep)
      end
    end

    def graph_checkable?
      operator_platform_id.present? && managed_platform_id.present? && errors.empty?
    end

    def downstream_of_managed?
      self.class.reachable_ids(managed_platform_id, :down).include?(operator_platform_id)
    end

    def chain_depth
      self.class.chain_length(operator_platform_id, :up) + 1 + self.class.chain_length(managed_platform_id, :down)
    end

    def acceptable_delegation
      return errors.add(:delegated_from, :blank) unless delegated_from

      validate_parent_edge
      errors.add(:granted_scopes, :exceeds_parent) if (Array(granted_scopes) - delegated_from.granted_scopes).any?
      errors.add(:delegated_from, :too_deep) if delegation_depth > BetterTogether::PlatformAssociation::MAX_DEPTH
    end

    def validate_parent_edge
      parent = delegated_from
      same_target = parent.managed_platform_id == managed_platform_id && parent.relation == relation
      errors.add(:delegated_from, :invalid) unless same_target && parent.id != id
      errors.add(:delegated_from, :no_upstream_edge) unless upstream_edge
    end

    def delegation_depth
      depth = 0
      node = delegated_from
      while node
        depth += 1
        return Float::INFINITY if depth > BetterTogether::PlatformAssociation::MAX_DEPTH + 1

        node = node.delegated_from
      end
      depth
    end
  end
end
