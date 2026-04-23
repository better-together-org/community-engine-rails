# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::C3::Contributions', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_headers) do
    api_auth_headers(regular_user)
      .merge('CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json')
  end
  let(:json_headers) { platform_manager_headers.merge('CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json') }
  let(:service_application) do
    create(:better_together_oauth_application, owner: platform_manager_user.person, scopes: 'read write admin')
  end
  let(:service_token) do
    create(:better_together_oauth_access_token,
           :client_credentials,
           application: service_application,
           scopes: 'read write admin')
  end
  let(:service_headers) do
    {
      'Authorization' => "Bearer #{service_token.token}",
      'CONTENT_TYPE' => 'application/json',
      'ACCEPT' => 'application/json'
    }
  end
  let(:fake_token_class) do
    Struct.new(
      :id, :earner, :contribution_type, :contribution_type_name, :c3_millitokens,
      :source_ref, :source_system, :units, :duration_s, :metadata, :status, :emitted_at, :confirmed_at,
      keyword_init: true
    ) do
      def c3_amount
        c3_millitokens.to_f / 10_000
      end
    end
  end
  let(:fake_balance_class) do
    Struct.new(:available_c3, keyword_init: true) do
      def credit!(amount)
        self.available_c3 += amount
      end

      def reload
        self
      end
    end
  end
  let(:params) do
    {
      contribution: {
        source_ref: 'job-123',
        source_system: 'borgberry',
        node_id: 'test-node-1',
        contribution_type: 'compute_cpu',
        c3_amount: '1.5',
        units: '15'
      }
    }
  end

  before do
    stub_const('BetterTogether::Fleet::Node', Class.new do
      def self.find_by(*)
        nil
      end
    end)
    fleet_node = Struct.new(:owner, keyword_init: true).new(owner: platform_manager_user.person)
    allow(BetterTogether::Fleet::Node).to receive(:find_by).with(node_id: 'test-node-1').and_return(fleet_node)

    token_struct = fake_token_class
    token_class = Class.new
    token_class.const_set(:MILLITOKEN_SCALE, 10_000)
    token_class.singleton_class.attr_accessor :stored_token, :create_calls
    token_class.define_singleton_method(:transaction) { |&block| block.call }
    token_class.define_singleton_method(:find_or_create_by!) do |source_system:, source_ref:, &block|
      self.create_calls ||= 0
      self.create_calls += 1

      return stored_token if stored_token

      self.stored_token = token_struct.new(
        id: 'token-1',
        source_system:,
        source_ref:,
        c3_millitokens: 0
      )
      block.call(stored_token)
      stored_token
    end

    balance_struct = fake_balance_class
    balance_class = Class.new
    balance_class.singleton_class.attr_accessor :stored_balance
    balance_class.define_singleton_method(:find_or_create_by!) do |**|
      self.stored_balance ||= balance_struct.new(available_c3: 0.0)
    end
    balance_class.define_singleton_method(:find_by!) { |**| stored_balance }

    stub_const('BetterTogether::C3::Token', token_class)
    stub_const('BetterTogether::C3::Balance', balance_class)
  end

  describe 'POST /api/v1/c3/contributions' do
    it 'treats a repeated contribution as duplicate without double-crediting the balance' do
      post '/api/v1/c3/contributions', params: params.to_json, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(BetterTogether::C3::Token.stored_token).to be_present
      expect(BetterTogether::C3::Balance.find_by!(holder: platform_manager_user.person, community: nil).available_c3).to eq(1.5)

      post '/api/v1/c3/contributions', params: params.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('status' => 'duplicate')
      expect(BetterTogether::C3::Token.create_calls).to eq(2)
      expect(BetterTogether::C3::Balance.find_by!(holder: platform_manager_user.person, community: nil).reload.available_c3).to eq(1.5)
    end

    it 'rejects contributions for nodes without a configured owner' do
      allow(BetterTogether::Fleet::Node).to receive(:find_by)
        .with(node_id: 'test-node-1')
        .and_return(Struct.new(:owner, keyword_init: true).new(owner: nil))

      post '/api/v1/c3/contributions', params: params.to_json, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to include('error' => "node 'test-node-1' has no current owner")
    end

    it 'allows trusted OAuth service tokens to record contributions' do
      post '/api/v1/c3/contributions', params: params.to_json, headers: service_headers

      expect(response).to have_http_status(:created)
      expect(BetterTogether::C3::Balance.find_by!(holder: platform_manager_user.person, community: nil).available_c3).to eq(1.5)
    end

    it 'rejects regular authenticated users from recording contributions' do
      post '/api/v1/c3/contributions', params: params.to_json, headers: regular_headers

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to include('error' => 'forbidden')
    end
  end

  describe 'GET /api/v1/c3/balance' do
    it 'rejects regular authenticated users from reading node balances' do
      get '/api/v1/c3/balance', params: { node_id: 'test-node-1' }, headers: regular_headers

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to include('error' => 'forbidden')
    end
  end
end
