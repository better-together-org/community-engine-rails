# frozen_string_literal: true

module BetterTogether
  # Directed join stating that an operator platform may act on a managed platform within granted scopes.
  # Nothing is implied by type or location: every relationship is a consented, scoped, auditable row.
  # platform_id (PlatformRecord) always mirrors managed_platform_id so tenancy scoping follows the managed side.
  class PlatformManagement < PlatformRecord # rubocop:todo Metrics/ClassLength
    include PlatformManagementRules
    include PlatformManagementLifecycle

    SCOPES = %w[read support manage_members manage_content manage_settings billing].freeze
    TRANSPORTS = { direct: 'direct', http: 'http' }.freeze
    STATUSES = { requested: 'requested', active: 'active', suspended: 'suspended', revoked: 'revoked' }.freeze
    MAX_DEPTH = 4

    belongs_to :operator_platform, class_name: '::BetterTogether::Platform', inverse_of: :operating_platform_managements
    belongs_to :managed_platform, class_name: '::BetterTogether::Platform', inverse_of: :managed_platform_managements
    belongs_to :delegated_from, class_name: '::BetterTogether::PlatformManagement', optional: true,
                                inverse_of: :derived_edges
    belongs_to :requested_by, class_name: '::BetterTogether::Person', optional: true
    belongs_to :accepted_by, class_name: '::BetterTogether::Person', optional: true
    belongs_to :status_changed_by, class_name: '::BetterTogether::Person', optional: true
    has_many :derived_edges, class_name: '::BetterTogether::PlatformManagement', foreign_key: :delegated_from_id,
                             dependent: :destroy, inverse_of: :delegated_from

    enum :status, STATUSES, default: :requested, validate: true
    enum :transport, TRANSPORTS, default: :direct, validate: true, prefix: true

    before_validation :mirror_managed_platform, prepend: true
    before_validation :normalize_scopes

    validates :operator_platform_id, uniqueness: { scope: :managed_platform_id }
    validates :edge_uid, uniqueness: true, allow_nil: true
    validates :granted_scopes, presence: true
    validate :scopes_known
    validate :platform_types_allowed
    validate :platforms_differ
    validate :platform_matches_managed
    validate :transport_matches_locality
    validate :endpoints_immutable, on: :update
    validate :expiry_in_future, on: :create
    validate :acceptable_graph, on: :create
    validate :acceptable_delegation, if: :delegated_from_id?

    after_create_commit { audit('requested', scopes: granted_scopes, actor_id: requested_by_id) }

    scope :in_force, lambda {
      active.where(expires_at: nil).or(active.where(arel_table[:expires_at].gt(Time.current)))
    }
    scope :for_managed, ->(platform) { where(managed_platform_id: platform) }
    scope :for_operator, ->(platform) { where(operator_platform_id: platform) }

    def expired?(now = Time.current)
      expires_at.present? && expires_at <= now
    end

    def effective?(now = Time.current, seen = [])
      return false if seen.include?(id) || !active? || expired?(now)
      return true unless delegated_from

      trail = seen + [id]
      delegated_from.effective?(now, trail) && upstream_edge&.effective?(now, trail) == true
    end

    def effective_scopes(now = Time.current)
      return [] unless effective?(now)

      delegated_from ? granted_scopes & delegated_from.effective_scopes(now) : granted_scopes
    end

    # The operator's own edge over the delegator, the authority it travels through to reach the managed platform.
    def upstream_edge
      return unless delegated_from

      self.class.find_by(operator_platform_id:, managed_platform_id: delegated_from.operator_platform_id)
    end

    def to_s
      "#{operator_platform&.name} manages #{managed_platform&.name}"
    end

    class << self
      def operators_of(platform)
        BetterTogether::Platform.where(id: for_managed(platform).in_force.select(&:effective?).map(&:operator_platform_id))
      end

      def managed_by(platform)
        BetterTogether::Platform.where(id: for_operator(platform).in_force.select(&:effective?).map(&:managed_platform_id))
      end

      def effective_scopes_for(operator, managed)
        edge = find_by(operator_platform: operator, managed_platform: managed)
        edge ? edge.effective_scopes : []
      end

      # Query only: true when the person belongs to an operator platform holding an effective edge over the
      # platform (carrying the scope, when given). Not wired into Warden, JWT or policies yet.
      def authorizes?(actor, platform, scope: nil)
        person = actor.respond_to?(:person) ? actor.person : actor
        return false if person.blank? || platform.blank?

        edges = for_managed(platform).in_force.where(operator_platform_id: operator_platform_ids_of(person))
        edges.any? { |edge| edge.effective? && (scope.nil? || edge.effective_scopes.include?(scope.to_s)) }
      end

      def operator_platform_ids_of(person)
        BetterTogether::PersonPlatformMembership.where(member_id: person.id, status: 'active').select(:joinable_id)
      end
    end

    private

    def mirror_managed_platform
      self.platform_id = managed_platform_id if managed_platform_id.present?
    end

    def normalize_scopes
      self.granted_scopes = Array(granted_scopes).map(&:to_s).reject(&:blank?).uniq
    end

    def audit(event, **details)
      BetterTogether::TenancyAudit.record("platform_management.#{event}", edge_id: id, edge_uid:,
                                                                          operator_platform_id:, managed_platform_id:,
                                                                          platform_id: managed_platform_id, **details)
    end
  end
end
