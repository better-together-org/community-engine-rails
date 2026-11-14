# frozen_string_literal: true

module BetterTogether
  # Shared verification for public and authenticated form submissions.
  module BotProtectedSubmissions
    extend ActiveSupport::Concern

    private

    def bot_protected_submission_valid?(form_id:, resource:, scope: :public) # rubocop:todo Metrics/AbcSize
      return true if authorized_robot_for_submission_scope?(scope)

      result = BetterTogether::BotDefense::Challenge.verify(
        token: bot_defense_params[:token],
        form_id:,
        trap_values: bot_defense_params[:trap_values] || {},
        user_agent: request.user_agent
      )

      return true if result.success?

      Rails.logger.warn(
        "Bot defense rejected #{form_id} submission [#{result.error}] path=#{request.fullpath} ip=#{request.remote_ip}"
      )
      resource.errors.add(:base, bot_defense_error_message(result.error))
      false
    end

    def bot_defense_params
      params.fetch(:bot_defense, ActionController::Parameters.new)
            .permit(:token, trap_values: {})
    end

    def authorized_robot_for_submission_scope?(scope)
      return false unless respond_to?(:current_robot, true)
      return false unless current_robot.present?

      required_scope = scope.to_sym == :authenticated ? 'submit_authenticated_forms' : 'submit_public_forms'
      current_robot.allows_bot_scope?(required_scope)
    end

    def bot_defense_error_message(error)
      I18n.t(
        "better_together.bot_defense.errors.#{error}",
        default: I18n.t(
          'better_together.bot_defense.errors.generic',
          default: 'Security verification failed. Please try again.'
        )
      )
    end
  end
end
