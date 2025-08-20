# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Offer
    class OffersController < JoatuController # rubocop:todo Metrics/ClassLength
      def show
        super
        mark_match_notifications_read_for(resource_instance)
      end

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def index # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        # Eager-load translated attributes (string/text/rich text) and the
        # creator's string translations to avoid N+1 lookups when rendering
        # lists and previews.
        @joatu_offers = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        ).with_translations.includes(categories: :string_translations, creator: %i[string_translations
                                                                                   profile_image_attachment profile_image_blob])

        # Build options for the filter form
        @category_options = BetterTogether::Joatu::CategoryOptions.call

        # Aggregate potential matches for all of the current user's offers (policy-scoped),
        # with sensible limits to avoid heavy queries.
        if helpers.current_person
          max_offers = (ENV['JOATU_AGG_MATCH_MAX_OFFERS'] || 25).to_i
          max_per_offer = (ENV['JOATU_AGG_MATCH_PER_OFFER'] || 10).to_i
          max_total_matches = (ENV['JOATU_AGG_MATCH_TOTAL'] || 50).to_i

          my_offers_scope = policy_scope(BetterTogether::Joatu::Offer)
                            .where(creator_id: helpers.current_person.id)
                            .order(created_at: :desc)
                            .limit(max_offers)

          request_offer_map = {}
          request_ids = []

          my_offers_scope.find_each(batch_size: 10) do |offer|
            break if request_ids.size >= max_total_matches

            BetterTogether::Joatu::Matchmaker
              .match(offer)
              .limit([max_per_offer, (max_total_matches - request_ids.size)].min)
              .each do |req|
                next if request_offer_map.key?(req.id)

                request_offer_map[req.id] = offer
                request_ids << req.id
              end
          end

          @offer_match_request_map = request_offer_map
          @aggregated_request_matches = if request_ids.any?
                                          BetterTogether::Joatu::Request.where(id: request_ids.uniq)
                                                                        .with_translations
                                                                        .includes(categories: :string_translations, creator: %i[string_translations
                                                                                                                                profile_image_attachment profile_image_blob])
                                        else
                                          BetterTogether::Joatu::Request.none
                                        end
        else
          @offer_match_request_map = {}
          @aggregated_request_matches = BetterTogether::Joatu::Request.none
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      def respond_with_request
        source = set_resource_instance
        authorize_resource
        redirect_to new_joatu_request_path(source_type: resource_class.to_s, source_id: source.id)
      end

      # Render new with optional prefill from a source Request/Offer
      def new # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength
        resource_instance
        # If source params were provided, load and authorize the source so the view can safely render it
        if (source_type = params[:source_type].presence) && (source_id = params[:source_id].presence)
          source_klass = source_type.to_s.safe_constantize
          @source = source_klass&.with_translations&.includes(:categories, :address,
                                                              creator: :string_translations)&.find_by(id: source_id)
          begin
            authorize @source if @source
          rescue Pundit::NotAuthorizedError
            render_not_found and return
          end

          # Only allow responding to sources that are open or already matched
          # :todo Metrics/BlockNesting, rubocop:todo Layout/LineLength, rubocop:todo Metrics/PerceivedComplexity,
          redirect_to url_for(@source.becomes(@source.class)),
                      alert: 'Cannot create a response for a source that is not open or matched.' and return

        end

        apply_source_prefill_offer(resource_instance)
      end

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def create # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        resource_instance(resource_params)
        authorize_resource

        respond_to do |format| # rubocop:todo Metrics/BlockLength
          if @resource.save
            # Controller-side fallback: if source params were provided but no nested response_link was created,
            # create a ResponseLink linking the source Request -> this Offer.
            source_type = params[:source_type] || params.dig(resource_name, :source_type)
            source_id = params[:source_id] || params.dig(resource_name, :source_id)

            if source_type == 'BetterTogether::Joatu::Request' && source_id.present?
              source = BetterTogether::Joatu::Request.find_by(id: source_id)
              if source
                # rubocop:todo Metrics/BlockNesting
                if source.respond_to?(:status) && !%w[open matched].include?(source.status)
                  Rails.logger.warn(
                    "Not creating response link: source #{source.id} status #{source.status} not respondable"
                  )
                elsif !BetterTogether::Joatu::ResponseLink.exists?(source: source, response: @resource)
                  BetterTogether::Joatu::ResponseLink.create(source: source, response: @resource,
                                                             creator_id: helpers.current_person&.id)
                end
                # rubocop:enable Metrics/BlockNesting
              end
            end

            format.html do
              redirect_to url_for(@resource.becomes(resource_class)),
                          notice: "#{resource_class.model_name.human} was successfully created."
            end
            format.turbo_stream do
              flash.now[:notice] = "#{resource_class.model_name.human} was successfully created."
              redirect_to url_for(@resource.becomes(resource_class))
            end
          else
            format.turbo_stream do
              render status: :unprocessable_entity, turbo_stream: [
                turbo_stream.replace(helpers.dom_id(@resource, 'form'),
                                     partial: 'form',
                                     locals: { resource_name.to_sym => @resource }),
                turbo_stream.update('form_errors',
                                    partial: 'layouts/better_together/errors',
                                    locals: { object: @resource })
              ]
            end
            format.html { render :new, status: :unprocessable_entity }
          end
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      private

      # Build an offer prefilled from a source Request when source params are present
      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def apply_source_prefill_offer(offer) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        return unless offer

        source_type = params[:source_type] || params.dig(resource_name, :source_type)
        source_id = params[:source_id] || params.dig(resource_name, :source_id)

        return unless source_type == 'BetterTogether::Joatu::Request' && source_id.present?

        source = BetterTogether::Joatu::Request.with_translations.includes(:categories, :address,
                                                                           creator: :string_translations).find_by(id: source_id)
        return unless source
        # Do not build nested response_link if source is not respondable
        return unless source.respond_to?(:status) ? %w[open matched].include?(source.status) : true

        offer.name ||= source.name
        offer.description ||= source.description
        offer.target_type ||= source.target_type if source.respond_to?(:target_type)
        offer.target_id ||= source.target_id if source.respond_to?(:target_id)
        offer.urgency ||= source.urgency if source.respond_to?(:urgency)
        offer.address || offer.build_address
        if source.respond_to?(:categories) && offer.category_ids.blank?
          offer.category_ids = source.categories.pluck(:id)
        end

        return unless offer.response_links_as_response.blank?

        offer.response_links_as_response.build(source_type: source.class.to_s, source_id: source.id,
                                               creator_id: helpers.current_person&.id)
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      protected

      def resource_class
        ::BetterTogether::Joatu::Offer
      end

      # Override the base resource collection to eager-load translations and
      # commonly accessed associations (categories, address) and the
      # creator's string translations to avoid N+1 queries in views.
      def resource_collection
        @resources ||= policy_scope(resource_class.with_translations)
                       .includes(:address,
                                 { categories: :string_translations },
                                 { creator: %i[string_translations profile_image_attachment profile_image_blob] })

        instance_variable_set("@#{resource_name(plural: true)}", @resources)
      end

      def resource_params
        rp = super
        rp[:creator_id] ||= helpers.current_person&.id
        rp
      end
    end
  end
end
