# frozen_string_literal: true

module BetterTogether
  # Authenticates the app user. Uses Devise.
  class User < ApplicationRecord
    include ::BetterTogether::DeviseUser

    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
    devise :database_authenticatable, :omniauthable, :registerable, :zxcvbnable,
           :recoverable, :rememberable, :validatable, :confirmable,
           :jwt_authenticatable,
           jwt_revocation_strategy: JwtDenylist,
           omniauth_providers: %i[github]

    has_one :person_identification,
            lambda {
              where(
                identity_type: 'BetterTogether::Person',
                active: true
              )
            },
            as: :agent,
            class_name: 'BetterTogether::Identification'

    has_one :person,
            through: :person_identification,
            source: :identity,
            source_type: 'BetterTogether::Person',
            autosave: true

    accepts_nested_attributes_for :person

    delegate :permitted_to?, to: :person, allow_nil: true

    def build_person(attributes = {})
      identification = build_person_identification(
        agent: self,
        identity_type: 'BetterTogether::Person',
        active: true
      )
      person = ::BetterTogether::Person.new(attributes)
      identification.identity = person
      person
    end

    # Override person method to ensure it builds if needed
    def person
      person_identification&.identity
    end

    # Custom person= method
    def person=(person_obj)
      if person_identification
        person_identification.identity = person_obj
      else
        build_person_identification(
          agent: self,
          identity: person_obj,
          identity_type: 'BetterTogether::Person',
          active: true
        )
      end
    end

    # Define person_attributes= method for nested attributes
    def person_attributes=(attributes)
      if person_identification&.identity
        # Update existing Person object
        person_identification.identity.assign_attributes(attributes)
      else
        # Build new Person object if it doesn't exist
        build_person(attributes)
      end
    end

    def to_s
      email
    end

    # TODO: accessing person here was causing save issues in the registration process due the the autobuild
    # def weak_words
    #   return [] unless person

    #   [person.name, person.slug, person.identifier]
    # end
  end
end
