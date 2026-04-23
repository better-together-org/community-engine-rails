# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      module Fleet
        # Fleet node registry API — borgberry fleet agents register and send heartbeats here.
        #
        # POST /api/v1/fleet/nodes          — register or update node (upsert by node_id)
        # GET  /api/v1/fleet/nodes          — list all nodes (optional ?online=true)
        # GET  /api/v1/fleet/nodes/:node_id — show single node
        # POST /api/v1/fleet/nodes/:node_id/heartbeat — update last_seen_at + capabilities
        class NodesController < BetterTogether::Api::ApplicationController # rubocop:todo Metrics/ClassLength
          ALLOWED_OWNER_TYPES = {
            'BetterTogether::Community' => BetterTogether::Community,
            'BetterTogether::Person' => BetterTogether::Person
          }.freeze

          class OwnerAuthorizationError < StandardError; end

          skip_after_action :verify_authorized, raise: false
          skip_after_action :verify_policy_scoped, raise: false
          skip_after_action :enforce_policy_use, raise: false
          require_oauth_scopes :read, only: %i[index show]
          require_oauth_scopes :write, only: %i[create heartbeat]
          before_action :require_fleet_service_access!

          def index
            nodes = BetterTogether::Fleet::Node.all
            nodes = nodes.online if params[:online] == 'true'

            render json: { nodes: nodes.map { |n| node_json(n) } }
          end

          def show
            node = BetterTogether::Fleet::Node.find_by!(node_id: params[:node_id])
            render json: { node: node_json(node) }
          rescue ActiveRecord::RecordNotFound
            render json: { error: "node '#{params[:node_id]}' not found" }, status: :not_found
          end

          def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
            node_data = node_params
            noise_key = node_data.delete(:borgberry_noise_public_key_base64)
            requested_owner = resolve_requested_owner(node_data)

            node = BetterTogether::Fleet::Node.find_or_initialize_by(node_id: node_data[:node_id])
            node.assign_attributes(node_data)
            node.registered_at ||= Time.current
            node.last_seen_at = Time.current
            node.online = true

            BetterTogether::Fleet::Node.transaction do
              # Store INEM public key inside services JSONB — no schema change required.
              if noise_key.present?
                node.services = (node.services || {}).merge('inem' => { 'noise_public_key_base64' => noise_key })
              end

              node.save!
              assign_node_owner!(node, requested_owner)
            end

            render json: { status: 'ok', node: node_json(node) }, status: node.previously_new_record? ? :created : :ok
          rescue ActiveRecord::RecordNotFound => e
            render json: { error: e.message }, status: :not_found
          rescue ActiveRecord::RecordInvalid, ArgumentError => e
            render json: { error: e.message }, status: :unprocessable_entity
          rescue OwnerAuthorizationError => e
            render json: { error: e.message }, status: :forbidden
          end

          def heartbeat # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity
            node = BetterTogether::Fleet::Node.find_by(node_id: params[:node_id])
            return render json: { error: 'node not found' }, status: :not_found unless node

            node.mark_online!
            node.update!(
              hardware: payload_section(:hardware) || node.hardware,
              compute: payload_section(:compute) || node.compute,
              services: payload_section(:services) || node.services
            )
            node.assign_owner!(current_user.person) if node.owner.nil? && current_user&.person.present?

            render json: { status: 'ok', node_id: node.node_id, last_seen_at: node.last_seen_at }
          end

          private

          def node_params
            params.require(:node).permit(
              :node_id, :node_category, :headscale_ip, :lan_ip, :borgberry_port,
              :owner_id, :owner_type, :safety_tier, :online,
              # borgberry_noise_public_key_base64: Noise X25519 public key for INEM peer verification.
              # Stored inside services JSONB under key "inem" so no schema change is needed.
              :borgberry_noise_public_key_base64,
              hardware: {}, compute: {}, services: {}
            )
          end

          def node_json(node) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
            {
              id: node.id,
              node_id: node.node_id,
              node_category: node.node_category,
              headscale_ip: node.headscale_ip,
              lan_ip: node.lan_ip,
              borgberry_port: node.borgberry_port,
              online: node.online,
              last_seen_at: node.last_seen_at,
              registered_at: node.registered_at,
              safety_tier: node.safety_tier,
              owner_id: node.owner_id,
              owner_type: node.owner_type,
              hardware: node.hardware,
              compute: node.compute,
              services: node.services,
              borgberry_noise_public_key_base64: node.services&.dig('inem', 'noise_public_key_base64')
            }
          end

          def resolve_requested_owner(node_data)
            owner_type = node_data.delete(:owner_type)
            owner_id = node_data.delete(:owner_id)
            return nil if owner_type.blank? && owner_id.blank?
            raise ArgumentError, 'owner_type and owner_id must be provided together' if owner_type.blank? || owner_id.blank?

            owner_class = ALLOWED_OWNER_TYPES[owner_type]
            raise ArgumentError, "unsupported owner_type '#{owner_type}'" unless owner_class

            owner_class.find(owner_id)
          end

          def assign_node_owner!(node, requested_owner)
            actor = current_user&.person

            if requested_owner.present?
              authorize_owner_assignment!(node, requested_owner, actor)
              node.assign_owner!(requested_owner)
            elsif node.owner.nil? && actor.present?
              node.assign_owner!(actor)
            end
          end

          def authorize_owner_assignment!(node, requested_owner, actor)
            return if actor&.permitted_to?('manage_platform')
            return if actor.present? && requested_owner == actor && (node.owner.nil? || node.owner == actor)

            raise OwnerAuthorizationError, 'only platform managers may assign a fleet node to another owner'
          end

          def payload_section(key)
            value = params[key]
            return unless value.respond_to?(:to_unsafe_h)

            value.to_unsafe_h.presence
          end

          def require_fleet_service_access!
            require_trusted_oauth_application_or_platform_manager!
          end
        end
      end
    end
  end
end
