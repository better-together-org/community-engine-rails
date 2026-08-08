# frozen_string_literal: true

module BetterTogether
  # Public token-based review (show/accept/decline) plus authenticated
  # offer-creation and ending of a Billing::Sponsorship. Modeled on
  # InvitationsController's token-lookup pattern; simpler since Sponsorship
  # has no STI per-type subclassing or email-only-invitee path to resolve.
  class SponsorshipsController < ApplicationController
    prepend_before_action :find_sponsorship_by_token, only: %i[show accept decline]
    before_action :find_sponsorship_by_id, only: %i[end]
    before_action :authenticate_user!, only: %i[create accept decline end]
    skip_before_action :check_platform_privacy, if: -> { @sponsorship.present? }, only: %i[show accept decline]
    after_action :verify_authorized, except: %i[show]

    def create
      @sponsorship = build_sponsorship
      authorize @sponsorship

      @sponsorship.save ? deliver_offer_and_redirect : redirect_to_offer_failure
    end

    def show; end

    def accept
      authorize @sponsorship
      @sponsorship.accept!
      redirect_to sponsorship_path(@sponsorship.token, locale: I18n.locale),
                  notice: t('better_together.billing.sponsorship_accepted', default: 'Sponsorship offer accepted.')
    end

    def decline
      authorize @sponsorship
      @sponsorship.decline!
      redirect_to sponsorship_path(@sponsorship.token, locale: I18n.locale),
                  notice: t('better_together.billing.sponsorship_declined', default: 'Sponsorship offer declined.')
    end

    def end
      authorize @sponsorship
      @sponsorship.end!
      redirect_back fallback_location: main_app.root_path(locale: I18n.locale),
                    notice: t('better_together.billing.sponsorship_ended', default: 'Sponsorship ended.')
    end

    private

    def deliver_offer_and_redirect
      @sponsorship.notification_service.notify_offered
      redirect_to sponsorship_path(@sponsorship.token, locale: I18n.locale),
                  notice: t('better_together.billing.sponsorship_offer_sent', default: 'Your sponsorship offer was sent.')
    end

    def redirect_to_offer_failure
      redirect_back fallback_location: main_app.root_path(locale: I18n.locale),
                    alert: @sponsorship.errors.full_messages.to_sentence
    end

    def find_sponsorship_by_token
      @sponsorship = BetterTogether::Billing::Sponsorship.find_by(token: params[:token])
      render_not_found unless @sponsorship
    end

    def find_sponsorship_by_id
      @sponsorship = BetterTogether::Billing::Sponsorship.find(params[:id])
    end

    def build_sponsorship
      BetterTogether::Billing::Sponsorship.new(sponsor: resolved_sponsor, beneficiary: resolved_beneficiary, status: 'pending')
    end

    def resolved_sponsor
      resolve_owner(params[:sponsor_type], params[:sponsor_id])
    end

    def resolved_beneficiary
      resolve_owner(params[:beneficiary_type], params[:beneficiary_identifier])
    end

    def resolve_owner(type_name, identifier)
      klass_name = BetterTogether::Billing::OwnershipResolver.supported_owner_type_name(type_name)
      return if klass_name.blank? || identifier.blank?

      klass_name.constantize.friendly.find(identifier)
    rescue ActiveRecord::RecordNotFound, NameError
      nil
    end
  end
end
