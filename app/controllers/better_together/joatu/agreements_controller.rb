# frozen_string_literal: true

module BetterTogether
  module Joatu
    # AgreementsController manages offer-request agreements
    class AgreementsController < JoatuController
      # POST /joatu/requests/:request_id/agreements
      def create # rubocop:todo Metrics/MethodLength
        resource_instance(resource_params)
        authorize_resource
        # Support both nested params (joatu_agreement[offer_id]/[request_id])
        # and top-level params (offer_id/request_id) from UI buttons.
        @resource.offer_id ||= params[:offer_id]
        @resource.request_id ||= params[:request_id]

        respond_to do |format|
          if @resource.save
            respond_to_create_success(format)
          else
            respond_to_create_failure(format)
          end
        end
      end

      # rubocop:todo Metrics/MethodLength
      def respond_to_create_success(format) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        format.html do
          redirect_to url_for(@resource.becomes(resource_class)),
                      notice: t('better_together.joatu.agreements.create.success',
                                default: "#{resource_class.model_name.human} was successfully created.")
        end
        format.turbo_stream do
          flash.now[:notice] =
            t('better_together.joatu.agreements.create.success',
              default: "#{resource_class.model_name.human} was successfully created.")
          redirect_to url_for(@resource.becomes(resource_class))
        end
      end
      # rubocop:enable Metrics/MethodLength

      def respond_to_create_failure(format) # rubocop:todo Metrics/MethodLength
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
        format.html do
          render :new, status: :unprocessable_entity
        end
      end

      # GET /joatu/agreements/:id
      def show
        mark_notifications_read_for_record_id(@joatu_agreement.id)
        super
      end

      # POST /joatu/agreements/:id/accept
      def accept
        @joatu_agreement = set_resource_instance
        authorize @joatu_agreement
        begin
          @joatu_agreement.accept!
          redirect_to joatu_agreement_path(@joatu_agreement),
                      notice: t('flash.joatu.agreement.accepted')
        rescue BetterTogether::C3::Balance::InsufficientBalance
          redirect_to joatu_agreement_path(@joatu_agreement),
                      alert: insufficient_c3_alert(@joatu_agreement)
        rescue ActiveRecord::RecordInvalid => e
          redirect_to joatu_agreement_path(@joatu_agreement),
                      alert: e.record.errors.full_messages.to_sentence.presence || 'Unable to accept agreement'
        end
      end

      # POST /joatu/agreements/:id/reject
      def reject
        @joatu_agreement = set_resource_instance
        authorize @joatu_agreement
        @joatu_agreement.reject!
        redirect_to joatu_agreement_path(@joatu_agreement),
                    notice: t('flash.joatu.agreement.rejected')
      end

      # POST /joatu/agreements/:id/fulfill
      def fulfill
        @joatu_agreement = set_resource_instance
        authorize @joatu_agreement
        begin
          @joatu_agreement.fulfill!
          redirect_to joatu_agreement_path(@joatu_agreement),
                      notice: t('flash.joatu.agreement.fulfilled',
                                default: 'Agreement fulfilled — C3 transferred to offer creator.')
        rescue ActiveRecord::RecordInvalid => e
          redirect_to joatu_agreement_path(@joatu_agreement),
                      alert: e.record.errors.full_messages.to_sentence.presence || 'Unable to fulfill agreement'
        rescue BetterTogether::C3::Balance::InsufficientBalance => e
          redirect_to joatu_agreement_path(@joatu_agreement),
                      alert: e.message
        end
      end

      private

      # Build a plain-language flash message when a payer has insufficient C3 balance.
      # Uses Tree Seeds amounts rather than raw numbers or technical identifiers.
      def insufficient_c3_alert(agreement)
        payer_balance = BetterTogether::C3::Balance.find_by(
          holder: current_person, community: nil
        )
        current_millitokens = payer_balance&.available_millitokens.to_i
        price_millitokens = agreement.try(:offer)&.try(:c3_price_millitokens).to_i

        # rubocop:disable Style/FormatStringToken -- i18n %{key} interpolation, not Ruby format
        t('flash.joatu.agreement.insufficient_c3',
          needed: helpers.tree_seeds_display(price_millitokens),
          current: helpers.tree_seeds_display(current_millitokens),
          default: 'You need %{needed} to accept this offer. Your current balance is %{current}.')
        # rubocop:enable Style/FormatStringToken
      end

      def resource_class
        BetterTogether::Joatu::Agreement
      end
    end
  end
end
