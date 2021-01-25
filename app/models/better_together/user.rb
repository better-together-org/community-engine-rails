module BetterTogether
  class User < ApplicationRecord
    include ::BetterTogether::DeviseUser
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable, :confirmable,
           :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
    
    has_one :person_identification,
            -> {
              where(
                identity_type: 'BetterTogether::Person',
                active: true
              )
            },
            as: :agent,
            class_name: 'BetterTogether::Identification',
            autosave: true
    has_one :person,
          through: :person_identification,
          source: :identity,
          source_type: 'BetterTogether::Person'

    accepts_nested_attributes_for :person

    def build_person(attributes)
      self.build_person_identification(
        agent: self,
        identity: BetterTogether::Person.new(attributes)
      )
    end
  end
end
