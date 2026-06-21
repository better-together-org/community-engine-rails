# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Api::ApplicationResource do
  describe '.records' do
    it 'uses policy scope without emitting repeated show? warnings' do
      expect do
        BetterTogether::Api::V1::BlockResource.records(
          context: { current_user: nil, policy_used: -> {} }
        ).to_a
      end.not_to output.to_stdout
    end
  end
end
