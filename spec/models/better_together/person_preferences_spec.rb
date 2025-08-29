# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Person, type: :model do
  describe 'message opt-in preference' do
    it 'defaults to false and can be toggled to true' do
      person = create(:better_together_person)
      expect(person.preferences['receive_messages_from_members']).to be(false)

      person.update!(preferences: person.preferences.merge('receive_messages_from_members' => true))
      person.reload
      expect(person.preferences['receive_messages_from_members']).to be(true)
    end
  end
end

