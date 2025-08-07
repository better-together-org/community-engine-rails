# frozen_string_literal: true

module BetterTogether
  # Authenticates the app user. Uses Devise.
  class User < ApplicationRecord
    include ::BetterTogether::DeviseUser

    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable, :confirmable,
           :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

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
      build_person_identification(
        agent: self,
        identity: ::BetterTogether::Person.new(attributes)
      )&.identity
    end

    # Define person_attributes method to get attributes of associated Person
    def person
      # Check if a Person object exists and return its attributes
      super.present? ? super : build_person
    end

    # def person= arg
    #     build_person_identification(
    #     agent: self,
    #     identity: arg
    #   )&.identity
    # end

    # Define person_attributes= method
    def person_attributes=(attributes)
      # Check if a Person object already exists
      if person.present?
        # Update existing Person object
        person.update(attributes)
      else
        # Build new Person object if it doesn't exist
        build_person(attributes)
      end
    end

    def to_s
      email
    end
  end
end
