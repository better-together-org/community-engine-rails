# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  class ProfilingTestController < ApplicationController
    skip_before_action :check_platform_setup
    skip_before_action :check_platform_privacy
    skip_before_action :set_platform_invitation
    skip_before_action :handle_debug_mode
    skip_before_action :set_debug_headers

    def index
      head :ok
    end
  end
end

RSpec.describe BetterTogether::ProfilingTestController do
  before do
    routes.draw { get 'index' => 'better_together/profiling_test#index' }

    stub_const('Rack::MiniProfiler', Class.new do
      def self.authorize_request; end
    end)
    allow(Rack::MiniProfiler).to receive(:authorize_request)
    allow(controller).to receive(:current_user).and_return(current_user)
    allow(BetterTogether::Profiling).to receive(:enabled?).and_return(profiling_enabled)
  end

  let(:current_user) { instance_double(BetterTogether::User, permitted_to?: permitted, person: nil) }
  let(:permitted) { false }
  let(:profiling_enabled) { false }

  it 'does not authorize rack mini profiler when profiling is disabled' do
    get :index, params: { locale: 'en' }

    expect(response).to have_http_status(:ok)
    expect(Rack::MiniProfiler).not_to have_received(:authorize_request)
  end

  context 'when profiling is enabled' do
    let(:profiling_enabled) { true }

    it 'authorizes rack mini profiler for platform managers' do
      allow(current_user).to receive(:permitted_to?).with('manage_platform').and_return(true)

      get :index, params: { locale: 'en' }

      expect(response).to have_http_status(:ok)
      expect(Rack::MiniProfiler).to have_received(:authorize_request).once
    end

    it 'does not authorize rack mini profiler for users without platform permissions' do
      get :index, params: { locale: 'en' }

      expect(response).to have_http_status(:ok)
      expect(Rack::MiniProfiler).not_to have_received(:authorize_request)
    end
  end
end
