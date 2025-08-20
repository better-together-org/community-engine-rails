# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Request
    class RequestsController < JoatuController
      def show
        super
        mark_match_notifications_read_for(resource_instance)
      end

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def index # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        @joatu_requests = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        ).includes(:categories, :creator)

        # Build options for the filter form
        @category_options = BetterTogether::Joatu::CategoryOptions.call

        # Aggregate potential matches for all of the current user's requests (policy-scoped),
        # with sensible limits to avoid heavy queries.
        if helpers.current_person
          max_requests = (ENV['JOATU_AGG_MATCH_MAX_REQUESTS'] || 25).to_i
          max_per_request = (ENV['JOATU_AGG_MATCH_PER_REQUEST'] || 10).to_i
          max_total_matches = (ENV['JOATU_AGG_MATCH_TOTAL'] || 50).to_i

          my_requests_scope = policy_scope(BetterTogether::Joatu::Request)
                              .where(creator_id: helpers.current_person.id)
                              .order(created_at: :desc)
                              .limit(max_requests)

          offer_request_map = {}
          offer_ids = []

          my_requests_scope.find_each(batch_size: 10) do |request|
            break if offer_ids.size >= max_total_matches

            BetterTogether::Joatu::Matchmaker
              .match(request)
              .limit([max_per_request, (max_total_matches - offer_ids.size)].min)
              .each do |offer|
                next if offer_request_map.key?(offer.id)

                offer_request_map[offer.id] = request
                offer_ids << offer.id
              end
          end

          @request_match_offer_map = offer_request_map
          @aggregated_offer_matches = if offer_ids.any?
                                        BetterTogether::Joatu::Offer.where(id: offer_ids.uniq)
                                      else
                                        BetterTogether::Joatu::Offer.none
                                      end
        else
          @request_match_offer_map = {}
          @aggregated_offer_matches = BetterTogether::Joatu::Offer.none
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      # GET /joatu/requests/:id/matches
      def matches
        @joatu_request = set_resource_instance
        authorize_resource
        @matches = BetterTogether::Joatu::Matchmaker.match(@joatu_request)
      end

      # Redirect to new offer form prefilled from a source Request
      def respond_with_offer
        source = set_resource_instance
        authorize_resource
        redirect_to new_joatu_offer_path(source_type: BetterTogether::Joatu::Request.to_s, source_id: source.id)
      end

      # Render new with optional prefill from a source Offer/Request
      def new # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        resource_instance
        # If source params were provided, load and authorize the source so the view can safely render it
        if (source_type = params[:source_type].presence) && (source_id = params[:source_id].presence)
          source_klass = source_type.to_s.safe_constantize
          @source = source_klass&.find_by(id: source_id)
          begin
            authorize @source if @source
          rescue Pundit::NotAuthorizedError
            render_not_found and return
          end

          # Only allow responding to sources that are open or already matched
          if @source.respond_to?(:status) && !%w[open matched].include?(@source.status)
            redirect_to url_for(@source.becomes(@source.class)),
                        alert: 'Cannot create a response for a source that is not open or matched.' and return
          end
        end

        apply_source_prefill(resource_instance)
      end

      private

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def apply_source_prefill(request) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        return unless request

        # Accept source params either at top-level (hidden_field_tag in new) or nested inside the form params
        source_type = params[:source_type] || params.dig(resource_name, :source_type)
        source_id = params[:source_id] || params.dig(resource_name, :source_id)

        return unless source_type == 'BetterTogether::Joatu::Offer' && source_id.present?

        source = BetterTogether::Joatu::Offer.find_by(id: source_id)
        return unless source
        # Do not build nested response_link if source is not respondable
        return unless source.respond_to?(:status) ? %w[open matched].include?(source.status) : true

        request.name ||= source.name
        request.description ||= source.description
        request.target_type ||= source.target_type if source.respond_to?(:target_type)
        request.target_id ||= source.target_id if source.respond_to?(:target_id)
        request.urgency ||= source.urgency if source.respond_to?(:urgency)
        request.address || request.build_address
        if source.respond_to?(:categories) && request.category_ids.blank?
          request.category_ids = source.categories.pluck(:id)
        end

        # Build a nested response_link so the form's fields_for will render hidden fields
        return unless request.response_links_as_response.blank?

        request.response_links_as_response.build(source_type: source.class.to_s, source_id: source.id,
                                                 creator_id: helpers.current_person&.id)
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      def resource_class
        ::BetterTogether::Joatu::Request
      end

      def resource_params
        rp = super
        rp[:creator_id] ||= helpers.current_person&.id
        rp
      end
    end
  end
end
