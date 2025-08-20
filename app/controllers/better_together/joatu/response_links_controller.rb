# frozen_string_literal: true

module BetterTogether
  module Joatu
    class ResponseLinksController < JoatuController # rubocop:todo Style/Documentation
      before_action :authenticate_user!
      # This controller doesn't call Pundit's `authorize` in the create flow
      # because it builds responses from an existing source. The global
      # `after_action :verify_authorized` from ResourceController would raise
      # an AuthorizationNotPerformedError after a redirect which can lead to a
      # DoubleRenderError (redirect then error render). Skip the check here.
      skip_after_action :verify_authorized

      def create # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        # Create a request from offer or offer from request, linking them via ResponseLink
        source_type = params[:source_type]
        source_id = params[:source_id]

        unless source_type && source_id
          return redirect_back fallback_location: joatu_hub_path,
                               alert: 'Invalid source'
        end

  source = source_type.constantize.with_translations.includes(:categories, :address, creator: :string_translations).find_by(id: source_id)
        return redirect_back fallback_location: joatu_hub_path, alert: 'Source not found' unless source

        # Only allow creating responses against sources that are open or already matched
        if source.respond_to?(:status) && !%w[open matched].include?(source.status)
          return redirect_back fallback_location: joatu_hub_path,
                               alert: 'Cannot respond to a source that is not open or matched.'
        end

        if source.is_a?(BetterTogether::Joatu::Offer)
          # Build a new Request from offer details
          request = BetterTogether::Joatu::Request.new
          request.name = source.name
          request.description = source.description
          request.creator_id = helpers.current_person&.id
          request.target_type = source.target_type if source.respond_to?(:target_type)
          request.target_id = source.target_id if source.respond_to?(:target_id)
          request.urgency = source.urgency if source.respond_to?(:urgency)
          request.address_id = source.address_id if source.respond_to?(:address_id)
          request.category_ids = source.categories.pluck(:id) if source.respond_to?(:categories)

          if request.save
            rl = ResponseLink.create(source: source, response: request, creator_id: helpers.current_person&.id)
            if rl.persisted?
              # mark_source_matched is handled in model callback
            else
              Rails.logger.error("Failed to create ResponseLink: #{rl.errors.full_messages.join(', ')}")
            end
            redirect_to joatu_request_path(request), notice: 'Request created in response to offer.'
          else
            redirect_back fallback_location: joatu_offer_path(source),
                          alert: request.errors.full_messages.to_sentence
          end
        elsif source.is_a?(BetterTogether::Joatu::Request)
          offer = BetterTogether::Joatu::Offer.new
          offer.name = source.name
          offer.description = source.description
          offer.creator_id = helpers.current_person&.id
          offer.target_type = source.target_type if source.respond_to?(:target_type)
          offer.target_id = source.target_id if source.respond_to?(:target_id)
          offer.urgency = source.urgency if source.respond_to?(:urgency)
          offer.address_id = source.address_id if source.respond_to?(:address_id)
          offer.category_ids = source.categories.pluck(:id) if source.respond_to?(:categories)

          if offer.save
            rl = ResponseLink.create(source: source, response: offer, creator_id: helpers.current_person&.id)
            unless rl.persisted?
              Rails.logger.error("Failed to create ResponseLink: #{rl.errors.full_messages.join(', ')}")
            end
            redirect_to joatu_offer_path(offer), notice: 'Offer created in response to request.'
          else
            redirect_back fallback_location: joatu_request_path(source),
                          alert: offer.errors.full_messages.to_sentence
          end
        else
          redirect_back fallback_location: joatu_hub_path, alert: 'Unsupported source type'
        end
      rescue StandardError => e
        # Log full backtrace to surface errors during tests
        Rails.logger.error(
          "ResponseLinksController#create failed: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        )
        raise
      end
    end
  end
end
