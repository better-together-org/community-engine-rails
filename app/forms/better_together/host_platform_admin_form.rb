module BetterTogether
  class HostPlatformAdminForm < ::Reform::Form
    MODEL_CLASS = ::BetterTogether::User
    model :user, namespace: :better_together

    property :username
    property :email
    property :password
    property :password_confirmation

    property :person do
      property :name
      property :description
    end

    # Validations for User
    validates :username, presence: true, length: { minimum: 3, maximum: 255 }
    validates :email, presence: true
    validate :valid_email
    validates :password, presence: true, length: { minimum: 6 }, length: { minimum: Devise.password_length.min }
    validates :password_confirmation, presence: true

    validate :password_match

    # Validations for Person (nested identi)
    validates :person, presence: true
    validates :name, presence: true, length: { minimum: 3, maximum: 191 }, on: :person
    validates :description, presence: true, length: { maximum: 1000 }, on: :person

    private

    def password_match
      errors.add(:password_confirmation, "doesn't match Password") if password != password_confirmation
    end

    def valid_email
      errors.add(:email, 'is not a valid email') unless email =~ URI::MailTo::EMAIL_REGEXP
    end
  end
end
