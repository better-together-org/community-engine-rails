# frozen_string_literal: true

module BetterTogether
  module Fleet
    # FleetNode represents a borgberry fleet node's capability record in CE.
    # Authoritative source for node identity, hardware capabilities, and online status.
    # Synced from borgberry fleet registry via POST /api/v1/fleet/nodes (heartbeat).
    class Node < ApplicationRecord
      self.table_name = 'better_together_fleet_nodes'

      NODE_CATEGORIES = %w[cat1 cat2 cat3].freeze
      SAFETY_TIERS = %w[T0 T1 T2 T3].freeze

      belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
      has_one :node_ownership,
              class_name: 'BetterTogether::Fleet::NodeOwnership',
              foreign_key: :node_id,
              dependent: :destroy,
              inverse_of: :node

      has_many :agent_job_results, class_name: 'BetterTogether::AgentJobResult',
                                   foreign_key: :fleet_node_id, dependent: :nullify, inverse_of: :fleet_node

      has_many :c3_tokens, class_name: 'BetterTogether::C3::Token',
                           as: :earner, dependent: :restrict_with_error

      validates :node_id, presence: true, uniqueness: true
      validates :node_category, presence: true, inclusion: { in: NODE_CATEGORIES }
      validates :safety_tier, inclusion: { in: SAFETY_TIERS, allow_nil: true }

      scope :online, -> { where(online: true) }
      scope :cat1, -> { where(node_category: 'cat1') }
      scope :cat2, -> { where(node_category: 'cat2') }

      # GPU type derived from hardware jsonb
      def gpu_type
        hardware['gpu_type'] || 'cpu'
      end

      # Whether this node is capable of running GPU inference
      def gpu_capable?
        %w[cuda metal adreno].include?(gpu_type)
      end

      def mark_online!
        update!(online: true, last_seen_at: Time.current)
      end

      def mark_offline!
        update!(online: false)
      end

      def owner
        node_ownership&.owner
      end

      def owner_id
        node_ownership&.owner_id
      end

      def owner_type
        node_ownership&.owner_type
      end

      def assign_owner!(owner_record)
        if owner_record.nil?
          node_ownership&.destroy!
          return
        end

        if node_ownership
          node_ownership.update!(owner: owner_record)
        else
          create_node_ownership!(owner: owner_record)
        end
      end

      def to_s
        node_id
      end
    end
  end
end
