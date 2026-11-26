# frozen_string_literal: true

module BetterTogether
  # End, suspend, reinstate and leave actions shared by the platform and community membership controllers.
  # Each keeps the membership row as history and redirects back with a flash message.
  module MembershipLifecycleActions
    extend ActiveSupport::Concern

    def end_membership
      change_lifecycle(:end?, :ended) { |membership| membership.end!(reason: lifecycle_reason, actor: helpers.current_person) }
    end

    def suspend
      change_lifecycle(:suspend?, :suspended) do |membership|
        membership.suspend!(reason: lifecycle_reason, actor: helpers.current_person)
      end
    end

    def reinstate
      change_lifecycle(:reinstate?, :reinstated) { |membership| membership.reinstate!(actor: helpers.current_person) }
    end

    def leave
      change_lifecycle(:leave?, :left) do |membership|
        membership.end!(reason: 'left', actor: helpers.current_person)
      end
    end

    private

    def change_lifecycle(permission, outcome)
      membership = lifecycle_membership
      authorize membership, permission
      yield membership
      redirect_to lifecycle_redirect_path, notice: t("better_together.memberships.lifecycle.flash.#{outcome}"),
                                           status: :see_other
    rescue ActiveRecord::RecordInvalid => e
      redirect_to lifecycle_redirect_path, alert: e.record.errors.full_messages.to_sentence, status: :see_other
    end

    def lifecycle_reason
      params[:reason].to_s.strip.first(255).presence
    end
  end
end
