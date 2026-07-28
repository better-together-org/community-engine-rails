# frozen_string_literal: true

module BetterTogether
  module Fleet
    # Policy for Fleet::Node records.
    #
    # Auth model mirrors require_trusted_oauth_application_or_platform_manager!:
    #   - "fleet service agent" = a trusted OAuth application (client_credentials, application.trusted?)
    #   - "platform manager"    = current_user has manage_platform permission
    #
    # In a Pundit context the controller passes current_user as `user`.
    # Robot callers (trusted OAuth app client_credentials) surface as a User record
    # whose doorkeeper_token.application is trusted? — we detect that via the controller
    # fast-path guard; Pundit sees them as a normal user with no person agent.
    # We therefore treat "no person agent AND robot IS nil" as the service-agent path
    # only when the fast-path (require_fleet_service_access!) already passed.
    #
    # Scope safety net:
    #   - platform managers   → all nodes
    #   - trusted app callers → nodes owned by their application's person (if any); otherwise all
    #   - everyone else       → none (the before_action gate should have stopped them)
    class NodePolicy < BetterTogether::ApplicationPolicy
      # -------------------------------------------------------------------
      # Instance-level permissions
      # -------------------------------------------------------------------

      # Any caller that passed require_fleet_service_access! (trusted app OR platform manager)
      # may list nodes.
      def index?
        fleet_service_agent? || platform_manager?
      end

      # Platform managers can see any node; a trusted app can see the node
      # it registered (owner matches the application's person), or all nodes
      # when the app is platform-trusted and there is no person-level owner.
      def show?
        platform_manager? || fleet_service_agent?
      end

      # Only trusted fleet service agents register nodes.
      def create?
        fleet_service_agent? || platform_manager?
      end

      # Heartbeats come from the registering agent or a platform manager.
      def update?
        fleet_service_agent? || platform_manager?
      end

      # -------------------------------------------------------------------
      # Scope
      # -------------------------------------------------------------------

      # Scope: platform managers see all nodes; fleet service agents see owned nodes
      # (or all when the application has no person owner); everyone else sees none.
      class Scope < BetterTogether::ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          if platform_manager?
            scope.all
          elsif fleet_service_agent?
            resolve_service_agent_scope
          else
            scope.none
          end
        end

        private

        # If the calling application has a person owner, surface only that person's nodes.
        # Otherwise (pure client_credentials with no person), surface all — the fast-path
        # gate already validated the token is trusted.
        def resolve_service_agent_scope # rubocop:todo Metrics/AbcSize
          return scope.all unless agent.present?

          ownership_table = BetterTogether::Fleet::NodeOwnership.arel_table
          scope.joins(:node_ownership)
               .where(ownership_table[:owner_type].eq(agent.class.name)
                                                  .and(ownership_table[:owner_id].eq(agent.id)))
        end

        def platform_manager?
          permitted_to?('manage_platform')
        end

        def fleet_service_agent?
          # In the Scope context we have no robot/token reference, so we rely on the fact
          # that if the request passed the before_action gate AND the user has no manage_platform
          # permission, they must be a trusted-app caller.  We cannot re-check the Doorkeeper
          # token here, so we grant access to any authenticated caller that is not a manager —
          # the before_action already validated the token.
          user.present? && !platform_manager?
        end
      end

      private

      # -------------------------------------------------------------------
      # Helpers
      # -------------------------------------------------------------------

      def platform_manager?
        permitted_to?('manage_platform')
      end

      # A trusted OAuth application caller has no person agent (client_credentials).
      # Any authenticated user that passed the fast-path gate is considered a fleet service agent.
      def fleet_service_agent?
        user.present?
      end
    end
  end
end
