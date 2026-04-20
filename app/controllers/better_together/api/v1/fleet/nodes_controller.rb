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
        class NodesController < BetterTogether::Api::ApplicationController
          skip_after_action :verify_authorized, raise: false
          skip_after_action :verify_policy_scoped, raise: false
          skip_after_action :enforce_policy_use, raise: false

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

          def create
            node_data = node_params
            node = BetterTogether::Fleet::Node.find_or_initialize_by(node_id: node_data[:node_id])
            node.assign_attributes(node_data)
            node.registered_at ||= Time.current
            node.last_seen_at = Time.current
            node.online = true
            node.save!

            render json: { status: 'ok', node: node_json(node) }, status: node.previously_new_record? ? :created : :ok
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          def heartbeat # rubocop:todo Metrics/AbcSize
            node = BetterTogether::Fleet::Node.find_by(node_id: params[:node_id])
            return render json: { error: 'node not found' }, status: :not_found unless node

            node.mark_online!
            node.update!(
              hardware: payload_section(:hardware) || node.hardware,
              compute: payload_section(:compute) || node.compute,
              services: payload_section(:services) || node.services
            )

            render json: { status: 'ok', node_id: node.node_id, last_seen_at: node.last_seen_at }
          end

          private

          def node_params
            params.require(:node).permit(
              :node_id, :node_category, :headscale_ip, :lan_ip, :borgberry_port,
              :safety_tier, :online,
              hardware: {}, compute: {}, services: {}
            )
          end

          def node_json(node) # rubocop:todo Metrics/MethodLength
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
              hardware: node.hardware,
              compute: node.compute,
              services: node.services
            }
          end

          def payload_section(key)
            value = params[key]
            return unless value.respond_to?(:to_unsafe_h)

            value.to_unsafe_h.presence
          end
        end
      end
    end
  end
end
