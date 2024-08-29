# frozen_string_literal: true

module BetterTogether
  module Users
    # Override default Devise registrations controller
    class RegistrationsController < ::Devise::RegistrationsController
      include DeviseLocales

      def create # rubocop:todo Metrics/MethodLength
        ActiveRecord::Base.transaction do
          super do |user|
            return unless user.persisted?

            user.build_person(person_params)

            if user.save!
              helpers.host_community.person_community_memberships.create!(
                member: user.person,
                role: ::BetterTogether::Role.find_by(identifier: 'community_member')
              )
            end
          end
        end
      end

      protected

      def person_params
        params.require(:user).require(:person_attributes).permit(%i[identifier name description])
      end
    end
  end
end
