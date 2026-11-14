# frozen_string_literal: true

module BetterTogether
  module BotDefense
    # Issues signed bot-defense challenges for non-HTML clients.
    class ChallengesController < ApplicationController
      skip_before_action :authenticate_user!, raise: false
      skip_before_action :check_platform_privacy

      def show
        challenge = BetterTogether::BotDefense::Challenge.issue(
          form_id: params[:form_id],
          user_agent: request.user_agent
        )

        render json: {
          token: challenge.token,
          trap_field: challenge.trap_field,
          min_submit_seconds: challenge.min_submit_seconds,
          expires_at: challenge.expires_at.iso8601
        }
      end
    end
  end
end
