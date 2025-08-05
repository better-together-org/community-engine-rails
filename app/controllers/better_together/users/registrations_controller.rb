# frozen_string_literal: true

module BetterTogether
  module Users
    # Override default Devise registrations controller
    class RegistrationsController < ::Devise::RegistrationsController
      include DeviseLocales

      skip_before_action :check_platform_privacy
      before_action :set_required_agreements, only: %i[new create]
      before_action :configure_sign_up_params, only: :create

      def new
        super do |user|
          user.email = @platform_invitation.invitee_email if @platform_invitation && user.email.empty?
        end
      end

      def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        unless agreements_accepted?
          build_resource(sign_up_params)
          resource.validate
          resource.errors.add(:base, t('devise.registrations.new.agreements_must_accept'))
          return respond_with(resource)
        end

        # rubocop:disable Metrics/BlockLength
        ActiveRecord::Base.transaction do
          super do |user|
            return unless user.persisted?

            user.build_person(person_params)

            if user.save!
              user.reload

              community_role = if @platform_invitation
                                 @platform_invitation.community_role
                               else
                                 ::BetterTogether::Role.find_by(identifier: 'community_member')
                               end

              helpers.host_community.person_community_memberships.create!(
                member: user.person,
                role: community_role
              )

              if @platform_invitation
                if @platform_invitation.platform_role
                  helpers.host_platform.person_platform_memberships.create!(
                    member: user.person,
                    role: @platform_invitation.platform_role
                  )
                end

                @platform_invitation.accept!(invitee: user.person)
              end

              record_agreements(user)
            end
          end
        end
        # rubocop:enable Metrics/BlockLength
      end

      protected

      def after_sign_up_path_for(resource)
        if is_navigational_format? && helpers.host_platform&.privacy_private?
          return better_together.new_user_session_path
        end

        super
      end

      def after_inactive_sign_up_path_for(resource)
        if is_navigational_format? && helpers.host_platform&.privacy_private?
          return better_together.new_user_session_path
        end

        super
      end

      def person_params
        params.require(:user).require(:person_attributes).permit(%i[identifier name description])
      end

      def agreements_accepted?
        params.require(:user)[:accept_terms_of_service] == '1' &&
          params.require(:user)[:accept_privacy_policy] == '1'
      end

      def set_required_agreements
        @terms_of_service = BetterTogether::Agreement.find_by(identifier: 'terms_of_service')
        @privacy_policy = BetterTogether::Agreement.find_by(identifier: 'privacy_policy')
      end

      def record_agreements(user)
        [@terms_of_service, @privacy_policy].each do |agreement|
          next unless agreement

          BetterTogether::AgreementParticipant.create!(
            agreement:, person: user.person, accepted_at: Time.current
          )
        end
      end

      def configure_sign_up_params
        devise_parameter_sanitizer.permit(:sign_up, keys: %i[accept_terms_of_service accept_privacy_policy])
      end
    end
  end
end
