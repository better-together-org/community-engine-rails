# frozen_string_literal: true

module BetterTogether
  module Users
    # Override default Devise registrations controller
    class RegistrationsController < ::Devise::RegistrationsController
      include DeviseLocales
      skip_before_action :check_platform_privacy

      def new
        super do |user|
          user.email = @platform_invitation.invitee_email if @platform_invitation && user.email.empty?
        end
      end

      def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        ActiveRecord::Base.transaction do
          super do |user|
            # byebug
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
            end
          end
        end
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
    end
  end
end
