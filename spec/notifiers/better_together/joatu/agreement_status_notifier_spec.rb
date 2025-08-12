# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    # rubocop:disable Metrics/BlockLength
    RSpec.describe AgreementStatusNotifier do
      let(:recipient) { double('Person') }
      let(:offer) { double('Offer', name: 'Offer') }
      let(:request) { double('Request', name: 'Request') }
      let(:agreement_class) do
        Class.new do
          attr_reader :offer, :request, :status, :id

          def self.name = 'Agreement'
          def self.has_query_constraints? = false
          def self.composite_primary_key? = false
          def self.primary_key = 'id'
          def self.polymorphic_name = name

          def initialize(offer:, request:, status: 'accepted')
            @offer = offer
            @request = request
            @status = status
            @id = 1
          end

          def _read_attribute(attr)
            instance_variable_get('@' + attr.to_s)
          end
        end
      end
      let(:agreement) { agreement_class.new(offer:, request:) }
      let(:notification) { double('Notification', recipient: recipient) }

      subject(:notifier) { described_class.new(record: agreement) }

      before do
        stub_const('Agreement', agreement_class)
      end

      it 'includes unread notification count in message' do
        unread = double('Unread', count: 2)
        allow(recipient).to receive(:notifications).and_return(double('Notifications', unread: unread))
        result = notifier.send(:build_message, notification)
        expect(result[:unread_count]).to eq(2)
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
