# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      module C3
        # Receives borgberry C3 contribution events after job completion.
        # Creates a C3::Token and credits the node owner's C3::Balance.
        #
        # POST /api/v1/c3/contributions
        #   body: { contribution: { source_ref, source_system, node_id, job_type,
        #                           contribution_type, units, c3_amount, duration_s,
        #                           metadata, emitted_at } }
        #
        # GET /api/v1/c3/contributions?node_id=bts-7&limit=20
        # GET /api/v1/c3/balance?node_id=bts-7
        class ContributionsController < BetterTogether::Api::ApplicationController # rubocop:todo Metrics/ClassLength
          MILLITOKEN_SCALE = BetterTogether::C3::Token::MILLITOKEN_SCALE
          skip_after_action :verify_authorized, raise: false
          skip_after_action :verify_policy_scoped, raise: false
          skip_after_action :enforce_policy_use, raise: false

          require_oauth_scopes :write, only: :create
          require_oauth_scopes :read, only: %i[index balance network_balance]
          before_action :require_c3_service_access!, except: :network_balance
          before_action :authorize_network_balance_access!, only: :network_balance

          def create # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
            contrib = contribution_params

            fleet_node = BetterTogether::Fleet::Node.find_by(node_id: contrib[:node_id])
            return render json: { error: "node '#{contrib[:node_id]}' not registered" }, status: :unprocessable_entity if fleet_node.nil?

            earner = fleet_node.owner
            return render_owner_not_configured(contrib[:node_id]) if earner.nil?

            c3_millitokens = (contrib[:c3_amount].to_f * MILLITOKEN_SCALE).round
            created = false

            token = BetterTogether::C3::Token.transaction do
              token = BetterTogether::C3::Token.find_or_create_by!(
                source_system: contrib[:source_system],
                source_ref: contrib[:source_ref]
              ) do |new_token|
                created = true
                new_token.earner = earner
                new_token.contribution_type = contrib[:contribution_type]
                new_token.contribution_type_name = contrib[:contribution_type]
                new_token.c3_millitokens = c3_millitokens
                new_token.units = contrib[:units]
                new_token.duration_s = contrib[:duration_s]
                new_token.metadata = contrib[:metadata] || {}
                new_token.status = 'confirmed'
                new_token.emitted_at = contrib[:emitted_at].presence || Time.current
                new_token.confirmed_at = Time.current
              end

              next token unless created

              balance = BetterTogether::C3::Balance.find_or_create_by!(
                holder: earner,
                community: nil
              )
              balance.credit!(token.c3_amount)
              token
            end

            if created
              balance = BetterTogether::C3::Balance.find_by!(holder: earner, community: nil)

              render json: {
                status: 'ok',
                token_id: token.id,
                c3_amount: token.c3_amount,
                new_balance: balance.reload.available_c3
              }, status: :created
            else
              render json: { status: 'duplicate', message: 'contribution already recorded' }, status: :ok
            end
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.message }, status: :unprocessable_entity
          rescue ActiveRecord::RecordNotUnique
            render json: { status: 'duplicate', message: 'contribution already recorded' }, status: :ok
          end

          def index # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
            node_id = params[:node_id]
            limit = [params.fetch(:limit, 20).to_i, 100].min

            tokens = if node_id.present?
                       fleet_node = BetterTogether::Fleet::Node.find_by(node_id: node_id)
                       return render json: { contributions: [] } if fleet_node.nil?

                       earner = fleet_node.owner
                       return render_owner_not_configured(node_id) if earner.nil?

                       BetterTogether::C3::Token
                         .where(earner: earner)
                         .order(created_at: :desc)
                         .limit(limit)
                     else
                       BetterTogether::C3::Token.order(created_at: :desc).limit(limit)
                     end

            render json: {
              contributions: tokens.map do |t|
                { id: t.id, source_ref: t.source_ref, contribution_type: t.contribution_type_name,
                  c3_amount: t.c3_amount, status: t.status, emitted_at: t.emitted_at }
              end
            }
          end

          def balance
            node_id = params.require(:node_id)
            fleet_node = BetterTogether::Fleet::Node.find_by(node_id: node_id)
            return render json: { error: "node '#{node_id}' not found" }, status: :not_found if fleet_node.nil?

            earner = fleet_node.owner
            return render_owner_not_configured(node_id) if earner.nil?

            bal = BetterTogether::C3::Balance.find_by(holder: earner, community: nil)

            render json: {
              node_id: node_id,
              available_c3: bal&.available_c3 || 0.0,
              locked_c3: bal&.locked_c3 || 0.0,
              lifetime_earned_c3: bal&.lifetime_earned_c3 || 0.0
            }
          end

          # GET /api/v1/c3/network_balance?borgberry_did=did:key:z6Mk...
          # Returns the aggregated C3 balance across all platforms where a person
          # has earned or received C3, identified by their portable borgberry DID.
          #
          # Access: own DID only, or platform administrator.
          # Optional: ?include_breakdown=true (admin scope required) — returns per-platform detail.
          def network_balance # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
            did = params.require(:borgberry_did)
            person = BetterTogether::Person.find_by(borgberry_did: did)

            unless person
              return render json: { error: "no person found with borgberry_did '#{did}'" },
                            status: :not_found
            end

            balances = BetterTogether::C3::Balance.where(holder: person)

            response_body = {
              borgberry_did: did,
              network_available_c3: balances.sum(:available_millitokens).to_f / MILLITOKEN_SCALE,
              network_locked_c3: balances.sum(:locked_millitokens).to_f / MILLITOKEN_SCALE,
              network_lifetime_c3: balances.sum(:lifetime_earned_millitokens).to_f / MILLITOKEN_SCALE,
              local_available_c3: balances.local.sum(:available_millitokens).to_f / MILLITOKEN_SCALE,
              federated_received_c3: balances.federated.sum(:available_millitokens).to_f / MILLITOKEN_SCALE
            }

            # Platform breakdown is opt-in and admin-only to protect cross-platform presence data.
            if params[:include_breakdown] == 'true' && current_platform_admin?
              response_body[:platform_breakdown] = balance_breakdown(balances)
            end

            render json: response_body
          end

          private

          def balance_breakdown(balances)
            balances.map do |b|
              {
                origin_platform_id: b.origin_platform_id,
                available_c3: b.available_c3,
                locked_c3: b.locked_c3,
                lifetime_earned_c3: b.lifetime_earned_c3,
                federated: b.origin_platform_id.present?
              }
            end
          end

          # Restricts network_balance to: the person whose DID is being queried,
          # or a platform administrator. Prevents cross-platform balance snooping.
          def authorize_network_balance_access!
            queried_did = params[:borgberry_did]
            return if current_user&.person&.borgberry_did == queried_did
            return if current_platform_admin?

            render json: { error: 'forbidden' }, status: :forbidden
          end

          def current_platform_admin?
            current_platform_manager?
          end

          def contribution_params
            params.require(:contribution).permit(
              :source_ref, :source_system, :node_id, :job_type, :contribution_type,
              :units, :c3_amount, :duration_s, :emitted_at, metadata: {}
            )
          end

          def render_owner_not_configured(node_id)
            render json: { error: "node '#{node_id}' has no current owner" }, status: :unprocessable_entity
          end

          def require_c3_service_access!
            require_trusted_oauth_application_or_platform_manager!
          end
        end
      end
    end
  end
end
