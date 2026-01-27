# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TimezoneScoped do
  let(:test_class) do
    Class.new do
      include BetterTogether::TimezoneScoped
    end
  end
  let(:instance) { test_class.new }

  before { configure_host_platform }

  describe '#resolve_timezone' do
    let(:platform) { create(:platform, time_zone: 'America/New_York') }
    let(:user) { create(:user) }

    before do
      user.person.update(time_zone: 'America/Los_Angeles')
    end

    context 'with explicit timezone parameter' do
      it 'returns explicit timezone (highest priority)' do
        result = instance.resolve_timezone(
          timezone: 'Europe/London',
          user: user,
          platform: platform
        )

        expect(result).to eq('Europe/London')
      end
    end

    context 'with recipient parameter' do
      let(:recipient) { create(:person, time_zone: 'Asia/Tokyo') }

      it 'returns recipient timezone when no explicit timezone' do
        result = instance.resolve_timezone(recipient: recipient, user: user, platform: platform)

        expect(result).to eq('Asia/Tokyo')
      end

      context 'when recipient is a User' do
        it 'extracts timezone from user.person' do
          result = instance.resolve_timezone(recipient: user)

          expect(result).to eq('America/Los_Angeles')
        end
      end
    end

    context 'with user parameter' do
      it 'returns user timezone when no recipient' do
        result = instance.resolve_timezone(user: user, platform: platform)

        expect(result).to eq('America/Los_Angeles')
      end

      it 'returns user.person.time_zone' do
        user.person.update(time_zone: 'Pacific/Auckland')
        result = instance.resolve_timezone(user: user)

        expect(result).to eq('Pacific/Auckland')
      end
    end

    context 'with platform parameter' do
      it 'returns platform timezone when no user or recipient' do
        result = instance.resolve_timezone(platform: platform)

        expect(result).to eq('America/New_York')
      end

      context 'with :host symbol' do
        it 'looks up host platform timezone' do
          # Use the existing host platform from configure_host_platform
          host_platform = BetterTogether::Platform.find_by(host: true)
          host_platform.update(time_zone: 'America/Chicago')
          result = instance.resolve_timezone(platform: :host)

          expect(result).to eq('America/Chicago')
        end
      end
    end

    context 'with application config timezone' do
      before do
        allow(Rails.application.config).to receive(:time_zone).and_return('Australia/Sydney')
      end

      it 'returns app config when no other sources available' do
        result = instance.resolve_timezone

        expect(result).to eq('Australia/Sydney')
      end
    end

    context 'with no timezone sources available' do
      before do
        allow(Rails.application.config).to receive(:time_zone).and_return(nil)
      end

      it 'falls back to UTC' do
        result = instance.resolve_timezone

        expect(result).to eq('UTC')
      end
    end

    context 'priority hierarchy' do
      let(:recipient) { create(:person, time_zone: 'Asia/Tokyo') }

      it 'respects priority: explicit > recipient > user > platform > app > UTC' do
        allow(Rails.application.config).to receive(:time_zone).and_return('Australia/Sydney')

        # All sources available - explicit wins
        result = instance.resolve_timezone(
          timezone: 'Europe/London',
          recipient: recipient,
          user: user,
          platform: platform
        )
        expect(result).to eq('Europe/London')

        # No explicit - recipient wins
        result = instance.resolve_timezone(recipient: recipient, user: user, platform: platform)
        expect(result).to eq('Asia/Tokyo')

        # No recipient - user wins
        result = instance.resolve_timezone(user: user, platform: platform)
        expect(result).to eq('America/Los_Angeles')

        # No user - platform wins
        result = instance.resolve_timezone(platform: platform)
        expect(result).to eq('America/New_York')

        # No platform - app config wins
        result = instance.resolve_timezone
        expect(result).to eq('Australia/Sydney')
      end
    end
  end

  describe '#with_timezone_scope' do
    it 'executes block in specified timezone' do
      original_zone = Time.zone.name

      instance.with_timezone_scope(timezone: 'America/New_York') do
        expect(Time.zone.name).to eq('America/New_York')
      end

      expect(Time.zone.name).to eq(original_zone)
    end

    it 'passes user timezone to block' do
      user = create(:user)
      user.person.update(time_zone: 'Pacific/Auckland')

      instance.with_timezone_scope(user: user) do
        expect(Time.zone.name).to eq('Pacific/Auckland')
      end
    end

    it 'returns block result' do
      result = instance.with_timezone_scope(timezone: 'UTC') do
        Time.current.zone
      end

      expect(result).to eq('UTC')
    end
  end

  describe 'controller integration' do
    let(:controller_class) do
      Class.new(ApplicationController) do
        include BetterTogether::TimezoneScoped

        attr_reader :current_user

        attr_writer :current_user
      end
    end
    let(:controller) { controller_class.new }
    let(:user) { create(:user) }

    before do
      user.person.update(time_zone: 'America/Los_Angeles')
      controller.current_user = user
    end

    it 'uses current_user timezone' do
      result = controller.resolve_timezone(user: :current)

      expect(result).to eq('America/Los_Angeles')
    end
  end

  describe 'MCP integration' do
    let(:mcp_tool_class) do
      Class.new do
        include BetterTogether::TimezoneScoped

        attr_accessor :current_user, :agent

        def initialize(user)
          @current_user = user
          @agent = user&.person
        end
      end
    end

    let(:user) { create(:user) }

    before do
      user.person.update(time_zone: 'Asia/Tokyo')
    end

    it 'resolves timezone from current_user' do
      tool = mcp_tool_class.new(user)

      result = tool.resolve_timezone

      # Falls back through priority: no explicit, no recipient, check user via current_user
      expect(result).to eq('Asia/Tokyo')
    end

    it 'executes tool logic in user timezone' do
      tool = mcp_tool_class.new(user)

      tool.with_timezone_scope(user: user) do
        expect(Time.zone.name).to eq('Asia/Tokyo')
      end
    end
  end

  describe 'backwards compatibility' do
    it 'provides determine_timezone method' do
      expect(instance).to respond_to(:determine_timezone)
    end

    it 'determine_timezone returns same as resolve_timezone' do
      user = create(:user)
      user.person.update(time_zone: 'Europe/Paris')

      expect(instance.determine_timezone(user: user)).to eq(instance.resolve_timezone(user: user))
    end
  end
end
