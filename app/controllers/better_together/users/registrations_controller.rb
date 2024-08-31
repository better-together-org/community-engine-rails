# frozen_string_literal: true

module BetterTogether
  module Users
    # Override default Devise registrations controller
    class RegistrationsController < ::Devise::RegistrationsController
      include DeviseLocales

      before_action :set_platform_invitation, only: %i[new create]

      def new
        super do |user|
          user.email = @platform_invitation.invitee_email if @platform_invitation and user.email.empty?
        end
      end

      def create # rubocop:todo Metrics/MethodLength
        ActiveRecord::Base.transaction do
          super do |user|
            return unless user.persisted?

            user.build_person(person_params)

            if user.save!
              if @platform_invitation
                community_role = @platform_invitation.community_role
              else
                community_role = ::BetterTogether::Role.find_by(identifier: 'community_member')
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

      def set_platform_invitation
        return unless params[:invitation_code].present?
        @platform_invitation = ::BetterTogether::PlatformInvitation.pending.find_by(token: params[:invitation_code])
      end

      def person_params
        params.require(:user).require(:person_attributes).permit(%i[identifier name description])
      end
    end
  end
end
