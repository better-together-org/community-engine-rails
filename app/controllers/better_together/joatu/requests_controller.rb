# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Request
    class RequestsController < JoatuController # rubocop:todo Metrics/ClassLength
      def show
        super
        mark_match_notifications_read_for(resource_instance)
      end

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def index # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        # Eager-load translated attributes and creator string translations
        @joatu_requests = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        ).with_translations.includes(categories: :string_translations, creator: %i[string_translations
                                                                                   profile_image_attachment profile_image_blob]) # rubocop:disable Layout/LineLength

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
                                                                    .with_translations
                                                                    .includes(categories: :string_translations, creator: %i[string_translations profile_image_attachment profile_image_blob]) # rubocop:disable Layout/LineLength
                                      else
                                        BetterTogether::Joatu::Offer.none
                                      end
        else
          @request_match_offer_map = {}
          @aggregated_offer_matches = BetterTogether::Joatu::Offer.none
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

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
          source_klass = joatu_source_class(source_type)
          return unless source_klass

          @source = source_klass&.with_translations&.includes(:categories, :address, creator: :string_translations)&.find_by(id: source_id) # rubocop:disable Layout/LineLength,Style/SafeNavigationChainLength
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
        apply_target_prefill(resource_instance)
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

        source = BetterTogether::Joatu::Offer.with_translations.includes(:categories, :address, creator: :string_translations).find_by(id: source_id) # rubocop:disable Layout/LineLength
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

      # Override the base resource collection to eager-load translations and
      # commonly accessed associations (categories, address) and the
      # creator's string translations to avoid N+1 queries in views.
      def resource_collection
        @resources ||= (index_action? ? policy_scope(resource_class.with_translations) : single_record_scope)
                       .includes(:address,
                                 { categories: :string_translations },
                                 { creator: %i[string_translations profile_image_attachment profile_image_blob] })

        instance_variable_set("@#{resource_name(plural: true)}", @resources)
      end

      def index_action?
        action_name == 'index'
      end

      # RequestPolicy::Scope deliberately excludes the MembershipRequest and
      # ConnectionRequest STI subtypes from the general listing scope (each has
      # its own dedicated policy Scope — see RequestPolicy::Scope::PRIVATE_REQUEST_TYPES).
      # That exclusion is correct for #index, but for single-record lookups
      # (show/edit/update/destroy/matches/respond_with_offer) it incorrectly
      # 404s access that the subtype's own policy would actually permit (e.g. a
      # platform manager viewing a MembershipRequest via the generic
      # /exchange/requests/:id path). Fold in the ids each subtype's own policy
      # scope makes visible so Pundit's per-instance #authorize (which resolves
      # the correct STI policy) gets a chance to run instead of being pre-empted.
      def single_record_scope
        visible_ids = policy_scope(resource_class).pluck(:id)
        visible_ids |= policy_scope(::BetterTogether::Joatu::MembershipRequest).pluck(:id)
        visible_ids |= policy_scope(::BetterTogether::Joatu::ConnectionRequest).pluck(:id)

        resource_class.with_translations.where(id: visible_ids)
      end

      # A private (standalone) Request that's excluded from the policy-scoped
      # resource_collection still exists on this platform — for an
      # unauthenticated visitor that reads as "please sign in", not a blanket
      # 404 (which would also incorrectly apply to genuinely missing requests /
      # requests on another platform).
      def handle_resource_not_found
        return super if current_user.present? || current_robot.present?

        request_record = platform_scoped_record_ignoring_privacy
        return super unless request_record

        redirect_to new_user_session_path(locale: I18n.locale)
      end

      def platform_scoped_record_ignoring_privacy
        platform = Current.platform || Current.host_platform
        return nil unless platform

        resource_class.where(platform_id: platform.id).friendly.find(id_param)
      rescue ActiveRecord::RecordNotFound, StandardError
        nil
      end

      def resource_params
        rp = super
        rp[:creator_id] ||= helpers.current_person&.id
        rp[:type] ||= requested_request_type if requested_resource_class.present?
        rp
      end

      def resource_instance(attrs = {})
        @resource ||= (requested_resource_class || resource_class).new(attrs)

        instance_variable_set("@#{resource_name}", @resource)
      end

      def requested_request_type
        @requested_request_type ||= params[:type].presence ||
                                    params.dig(:joatu_request, :type).presence ||
                                    params.dig(:better_together_joatu_connection_request, :type).presence
      end

      def requested_resource_class
        @requested_resource_class ||= if requested_request_type.present?
                                        allowed_request_classes.fetch(requested_request_type, nil)
                                      end
      end

      def allowed_request_classes
        {
          'BetterTogether::Joatu::Request' => ::BetterTogether::Joatu::Request,
          'BetterTogether::Joatu::ConnectionRequest' => ::BetterTogether::Joatu::ConnectionRequest
        }
      end

      def apply_target_prefill(request)
        return unless request.is_a?(::BetterTogether::Joatu::ConnectionRequest)
        return unless platform_target_params_present?

        @target = ::BetterTogether::Platform.find_by(id: prefill_target_id)
        return unless @target

        assign_target_to_request(request, @target)
      end

      def platform_target_params_present?
        prefill_target_type == 'BetterTogether::Platform' && prefill_target_id.present?
      end

      def prefill_target_type
        params[:target_type].presence || params.dig(resource_name.to_sym, :target_type).presence
      end

      def prefill_target_id
        params[:target_id].presence || params.dig(resource_name.to_sym, :target_id).presence
      end

      def assign_target_to_request(request, target)
        request.target ||= target
        request.target_type ||= target.class.to_s
        request.target_id ||= target.id
      end
    end
  end
end
