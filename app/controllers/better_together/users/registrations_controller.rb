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
          resource.errors.add(:base, I18n.t('devise.registrations.new.agreements_required'))
          respond_with resource
          return
        end

        ActiveRecord::Base.transaction do # rubocop:todo Metrics/BlockLength
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

              create_agreement_participants(user.person)
            end
          end
        end
      end

      protected

      def set_required_agreements
        @privacy_policy_agreement = BetterTogether::Agreement.find_by(identifier: 'privacy_policy')
        @terms_of_service_agreement = BetterTogether::Agreement.find_by(identifier: 'terms_of_service')
      end

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
        params[:privacy_policy_agreement] == '1' && params[:terms_of_service_agreement] == '1'
      end

      def create_agreement_participants(person)
        agreements = BetterTogether::Agreement.where(identifier: %w[privacy_policy terms_of_service])
        agreements.find_each do |agreement|
          BetterTogether::AgreementParticipant.create!(agreement: agreement, person: person)
        end
      end
    end
  end
end
