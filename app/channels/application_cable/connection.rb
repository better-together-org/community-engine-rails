# frozen_string_literal: true

module ApplicationCable
  # action cable connection
  class Connection < ActionCable::Connection::Base
    identified_by :current_person

    def connect
      self.current_person = find_verified_person
      logger.add_tags 'ActionCable', "Person #{current_person.id}"
    end

    protected

    def find_verified_person
      if (current_user = env['warden'].user)
        current_user.person
      else
        reject_unauthorized_connection
      end
    end
  end
end
