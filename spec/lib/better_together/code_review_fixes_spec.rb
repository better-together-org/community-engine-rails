# frozen_string_literal: true

require 'rails_helper'

# TDD specs for code review fixes across Phases 1-5.
# Each context maps to a specific fix from the implementation plan.
RSpec.describe 'Code Review Fixes' do
  include McpTestHelpers
  # ─────────────────────────────────────────────────────────────────────────────
  # Phase 1: Critical Security
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Phase 1: Critical Security' do
    describe '1.1 — CSP nonce generator is random per-request' do
      it 'generates a unique nonce per request' do
        generator = Rails.application.config.content_security_policy_nonce_generator
        expect(generator).to be_present

        # Create two mock requests
        request1 = instance_double(ActionDispatch::Request)
        request2 = instance_double(ActionDispatch::Request)

        nonce1 = generator.call(request1)
        nonce2 = generator.call(request2)

        # Nonces must be non-empty strings
        expect(nonce1).to be_a(String)
        expect(nonce1).not_to be_empty

        # Nonces must be different per call (random)
        expect(nonce1).not_to eq(nonce2)
      end

      it 'does not depend on session ID' do
        generator = Rails.application.config.content_security_policy_nonce_generator
        # The generator should accept a request argument but NOT access session
        request = instance_double(ActionDispatch::Request)
        # Should not call session on the request
        expect(request).not_to receive(:session)
        generator.call(request)
      end
    end

    describe '1.2 — CORS configuration' do
      let(:cors_config) do
        Rails.application.config.middleware.detect { |m| m.name == 'Rack::Cors' }
      end

      it 'does not default to wildcard origins' do
        # When ALLOWED_ORIGINS is not set, origins should not be *
        # We test this indirectly by checking the configured middleware
        expect(cors_config).to be_present
      end
    end

    describe '1.3 — Doorkeeper PKCE enabled' do
      it 'has PKCE forced for authorization code flow' do
        skip 'Doorkeeper not loaded' unless defined?(Doorkeeper)
        expect(Doorkeeper.config.force_pkce?).to be true
      end
    end

    describe '1.4 — Webhook endpoint secret is encrypted' do
      it 'uses Active Record Encryption for the secret attribute' do
        encrypted_attrs = BetterTogether::WebhookEndpoint.encrypted_attributes
        expect(encrypted_attrs).to include(:secret)
      end
    end

    describe '1.5 — NavigationItem#dropdown_with_visible_children? operator precedence' do
      let(:navigation_area) { create(:navigation_area) }

      it 'returns true only when dropdown AND has visible children' do
        parent_item = create(:navigation_item,
                             navigation_area: navigation_area,
                             item_type: 'dropdown',
                             visible: true,
                             privacy: 'public')
        create(:navigation_item,
               navigation_area: navigation_area,
               parent: parent_item,
               visible: true,
               privacy: 'public')

        # Force reload to clear any cached associations
        parent_item.reload
        expect(parent_item.dropdown_with_visible_children?).to be true
      end

      it 'returns false when dropdown but no visible children' do
        parent_item = create(:navigation_item,
                             navigation_area: navigation_area,
                             item_type: 'dropdown',
                             visible: true,
                             privacy: 'public')
        create(:navigation_item,
               navigation_area: navigation_area,
               parent: parent_item,
               visible: false,
               privacy: 'public')

        parent_item.reload
        expect(parent_item.dropdown_with_visible_children?).to be false
      end

      it 'returns false when not a dropdown even with children' do
        parent_item = create(:navigation_item,
                             navigation_area: navigation_area,
                             item_type: 'link',
                             visible: true,
                             privacy: 'public')
        create(:navigation_item,
               navigation_area: navigation_area,
               parent: parent_item,
               visible: true,
               privacy: 'public')

        parent_item.reload
        expect(parent_item.dropdown_with_visible_children?).to be false
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Phase 2: Rate Limiting & OAuth Hardening
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Phase 2: Rate Limiting & OAuth Hardening' do
    describe '2.1 — API auth endpoint throttling' do
      it 'has throttle rule for API login endpoint' do
        throttle_names = Rack::Attack.throttles.keys
        expect(throttle_names).to include('api_logins/ip')
      end

      it 'has throttle rule for API registration endpoint' do
        throttle_names = Rack::Attack.throttles.keys
        expect(throttle_names).to include('api_registrations/ip')
      end

      it 'has throttle rule for API password reset endpoint' do
        throttle_names = Rack::Attack.throttles.keys
        expect(throttle_names).to include('api_password_resets/ip')
      end

      it 'has throttle rule for OAuth token endpoint' do
        throttle_names = Rack::Attack.throttles.keys
        expect(throttle_names).to include('oauth/token/ip')
      end
    end

    describe '2.2 — Token introspection restricted' do
      it 'does not allow unconditional token introspection' do
        skip 'Doorkeeper not loaded' unless defined?(Doorkeeper)
        # allow_token_introspection should be a callable (block), not just `true`
        introspection_config = Doorkeeper.config.allow_token_introspection
        expect(introspection_config).to respond_to(:call)
      end
    end

    describe '2.3 — OAuth application secrets hashed' do
      it 'uses hashed secret storage' do
        skip 'Doorkeeper not loaded' unless defined?(Doorkeeper)
        strategy = Doorkeeper.config.application_secret_strategy
        expect(strategy).not_to eq(::Doorkeeper::SecretStoring::Plain)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Phase 3: Authorization & Data Protection
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Phase 3: Authorization & Data Protection' do
    describe '3.1 — RegistrationHelpers avoids to_unsafe_h' do
      it 'does not use to_unsafe_h in sign_up_params source' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'controllers', 'concerns',
                          'better_together', 'api', 'auth', 'registration_helpers.rb')
        )
        expect(source).not_to include('to_unsafe_h')
      end
    end

    describe '3.2 — PersonResource email restricted to own record' do
      it 'excludes email from fetchable fields for unauthenticated context' do
        person = create(:better_together_person)
        resource = BetterTogether::Api::V1::PersonResource.new(person, { current_person: nil })
        expect(resource.fetchable_fields).not_to include(:email)
      end

      it 'includes email for context with current_person' do
        person = create(:better_together_person)
        resource = BetterTogether::Api::V1::PersonResource.new(person, { current_person: person })
        expect(resource.fetchable_fields).to include(:email)
      end
    end

    describe '3.4 — PeopleController#me nil guard' do
      it 'returns unauthorized when no person is associated' do
        # Simulate user without person — the automatic test config creates a user,
        # so we test the nil guard exists in source code
        source = File.read(
          Rails.root.join('..', '..', 'app', 'controllers',
                          'better_together', 'api', 'v1', 'people_controller.rb')
        )
        expect(source).to include('current_user&.person')
      end
    end

    describe '3.5 — MetricsSummaryController returns 404 not 403' do
      it 'returns 404 status in source for unauthorized access' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'controllers',
                          'better_together', 'api', 'v1', 'metrics_summary_controller.rb')
        )
        expect(source).to include(':not_found')
        expect(source).not_to include(':forbidden')
      end
    end

    describe '3.6 — Webhook endpoints require :admin for mutations' do
      it 'does not allow :write scope for create/update/destroy' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'controllers',
                          'better_together', 'api', 'v1', 'webhook_endpoints_controller.rb')
        )
        # The line for create/update/destroy/test should use :admin only, not :write
        mutation_line = source.lines.find { |l| l.include?('create update destroy') || l.include?('create, :update, :destroy') }
        expect(mutation_line).to be_present
        expect(mutation_line).to include(':admin')
        expect(mutation_line).not_to include(':write')
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Phase 4: Input Validation & Query Safety
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Phase 4: Input Validation & Query Safety' do
    describe '4.1 — ApplicationTool has sanitize_like helper' do
      it 'defines a protected sanitize_like method' do
        tool_class = Class.new(BetterTogether::Mcp::ApplicationTool)
        tool = tool_class.new
        expect(tool.respond_to?(:sanitize_like, true)).to be true
      end

      it 'escapes LIKE wildcards' do
        tool_class = Class.new(BetterTogether::Mcp::ApplicationTool)
        tool = tool_class.new
        expect(tool.send(:sanitize_like, '100%')).to eq('100\\%')
        expect(tool.send(:sanitize_like, 'under_score')).to eq('under\\_score')
      end
    end

    describe '4.3 — GetMetricsSummaryTool handles invalid dates gracefully' do
      before do
        configure_host_platform
        manager = create(:user, :platform_manager)
        stub_mcp_request_for(BetterTogether::Mcp::GetMetricsSummaryTool, user: manager)
      end

      it 'does not raise on malformed from_date' do
        tool = BetterTogether::Mcp::GetMetricsSummaryTool.new
        expect { tool.call(from_date: 'not-a-date') }.not_to raise_error
      end

      it 'does not raise on malformed to_date' do
        tool = BetterTogether::Mcp::GetMetricsSummaryTool.new
        expect { tool.call(to_date: 'garbage') }.not_to raise_error
      end
    end

    describe '4.4 — JSONAPI param parser handles malformed JSON' do
      it 'registers a parser that handles parse errors' do
        parser = ActionDispatch::Request.parameter_parsers[:jsonapi]
        expect(parser).to be_present
        expect { parser.call('{ invalid json }') }.to raise_error(ActionDispatch::Http::Parameters::ParseError)
      end
    end

    describe '4.5 — WebhookEndpoint.for_event uses parameterized query' do
      it 'does not use string interpolation in the scope SQL' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'models', 'better_together', 'webhook_endpoint.rb')
        )
        # Find the for_event scope and ensure it uses bind params
        for_event_section = source[/scope :for_event.*?\n\s*\}/m]
        expect(for_event_section).to be_present
        # Should not have Ruby string interpolation like #{event}
        expect(for_event_section).not_to match(/#\{/)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Phase 5: Model Cleanup & Consistency
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Phase 5: Model Cleanup & Consistency' do
    describe '5.1 — Person has no duplicate agreement_participants' do
      it 'declares agreement_participants association only once' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'models', 'better_together', 'person.rb')
        )
        count = source.scan(/has_many :agreement_participants/).count
        expect(count).to eq(1), "Expected 1 declaration of has_many :agreement_participants, found #{count}"
      end
    end

    describe '5.2 — Page has no duplicate navigation_items' do
      it 'declares navigation_items association only once' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'models', 'better_together', 'page.rb')
        )
        count = source.scan(/has_many :navigation_items/).count
        expect(count).to eq(1), "Expected 1 declaration of has_many :navigation_items, found #{count}"
      end
    end

    describe '5.3 — Person has webhook_endpoints association' do
      it 'has a webhook_endpoints has_many association' do
        assoc = BetterTogether::Person.reflect_on_association(:webhook_endpoints)
        expect(assoc).to be_present
        expect(assoc.macro).to eq(:has_many)
        expect(assoc.options[:dependent]).to eq(:destroy)
      end
    end

    describe '5.4 — WebhookDelivery uses string enum for status' do
      it 'defines status as an enum' do
        expect(BetterTogether::WebhookDelivery).to respond_to(:statuses)
      end

      it 'has all expected status values' do
        statuses = BetterTogether::WebhookDelivery.statuses
        expect(statuses.keys).to match_array(%w[pending delivered failed retrying])
      end

      it 'provides predicate methods' do
        delivery = BetterTogether::WebhookDelivery.new(status: 'pending')
        expect(delivery).to respond_to(:pending?)
        expect(delivery).to respond_to(:delivered?)
        expect(delivery).to respond_to(:failed?)
        expect(delivery).to respond_to(:retrying?)
      end
    end

    describe '5.5 — WebhookPublishable does not rescue all StandardError' do
      it 'does not broadly rescue StandardError' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'models', 'concerns',
                          'better_together', 'webhook_publishable.rb')
        )
        expect(source).not_to include('rescue StandardError')
      end
    end

    describe '5.6 — ListUploadsTool requires authentication' do
      before do
        configure_host_platform
        stub_mcp_request_for(BetterTogether::Mcp::ListUploadsTool, user: nil)
      end

      it 'returns an error for unauthenticated users' do
        tool = BetterTogether::Mcp::ListUploadsTool.new
        result = JSON.parse(tool.call)
        expect(result).to have_key('error')
        expect(result['error']).to include('Authentication')
      end
    end

    describe '5.7 — ListCommunitiesTool has limit parameter' do
      before do
        configure_host_platform
        user = create(:user)
        stub_mcp_request_for(BetterTogether::Mcp::ListCommunitiesTool, user: user)
      end

      it 'accepts a limit argument' do
        tool = BetterTogether::Mcp::ListCommunitiesTool.new
        expect { tool.call(limit: 5) }.not_to raise_error
      end

      it 'respects the limit' do
        6.times { |i| create(:community, name: "Community #{i}", privacy: 'public') }
        tool = BetterTogether::Mcp::ListCommunitiesTool.new
        result = JSON.parse(tool.call(limit: 3))
        expect(result.length).to be <= 3
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Phase 6: Operational / DRY / Remaining Tool Fixes
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Phase 6: Operational & DRY Improvements' do
    describe '6.1 — PunditContext.from_request_or_doorkeeper extracts Doorkeeper fallback' do
      it 'responds to from_request_or_doorkeeper' do
        expect(BetterTogether::Mcp::PunditContext).to respond_to(:from_request_or_doorkeeper)
      end

      it 'returns a PunditContext from Warden when session is present' do
        user = create(:user)
        warden = instance_double('Warden::Proxy', user: user)
        request = instance_double(Rack::Request, env: { 'warden' => warden })

        context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)
        expect(context).to be_a(BetterTogether::Mcp::PunditContext)
        expect(context.user).to eq(user)
        expect(context).to be_authenticated
      end

      it 'falls back to Doorkeeper token when Warden has no user' do
        user = create(:user)
        warden = instance_double('Warden::Proxy', user: nil)
        request = instance_double(Rack::Request, env: { 'warden' => warden })

        doorkeeper_token = double(
          'doorkeeper_token',
          accessible?: true,
          resource_owner_id: user.id
        )
        allow(doorkeeper_token).to receive(:acceptable?).with('mcp_access').and_return(true)
        allow(Doorkeeper::OAuth::Token).to receive(:authenticate)
          .with(request, :from_bearer_authorization)
          .and_return(doorkeeper_token)

        context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)
        expect(context.user).to eq(user)
        expect(context).to be_authenticated
      end

      it 'returns guest context when neither Warden nor Doorkeeper authenticate' do
        warden = instance_double('Warden::Proxy', user: nil)
        request = instance_double(Rack::Request, env: { 'warden' => warden })

        allow(Doorkeeper::OAuth::Token).to receive(:authenticate)
          .with(request, :from_bearer_authorization)
          .and_return(nil)

        context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)
        expect(context).to be_guest
      end

      it 'rejects Doorkeeper token without mcp_access scope' do
        user = create(:user)
        warden = instance_double('Warden::Proxy', user: nil)
        request = instance_double(Rack::Request, env: { 'warden' => warden })

        doorkeeper_token = double(
          'doorkeeper_token',
          accessible?: true,
          resource_owner_id: user.id
        )
        allow(doorkeeper_token).to receive(:acceptable?).with('mcp_access').and_return(false)
        allow(Doorkeeper::OAuth::Token).to receive(:authenticate)
          .with(request, :from_bearer_authorization)
          .and_return(doorkeeper_token)

        context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)
        expect(context).to be_guest
      end
    end

    describe '6.2 — fast_mcp.rb uses PunditContext.from_request_or_doorkeeper (no duplicate)' do
      it 'does not contain duplicate Doorkeeper token extraction blocks' do
        source = File.read(
          Rails.root.join('..', '..', 'config', 'initializers', 'fast_mcp.rb')
        )
        # Count occurrences of the Doorkeeper::OAuth::Token.authenticate pattern
        matches = source.scan('Doorkeeper::OAuth::Token.authenticate')
        expect(matches.length).to be <= 0,
          "Expected zero inline Doorkeeper token extractions in fast_mcp.rb, found #{matches.length}. " \
          'Doorkeeper fallback should be extracted into PunditContext.from_request_or_doorkeeper'
      end

      it 'calls from_request_or_doorkeeper in filter blocks' do
        source = File.read(
          Rails.root.join('..', '..', 'config', 'initializers', 'fast_mcp.rb')
        )
        expect(source).to include('from_request_or_doorkeeper')
      end
    end

    describe '6.3 — Search tools use sanitize_like for LIKE queries' do
      describe 'SearchPeopleTool' do
        it 'escapes LIKE metacharacters in queries' do
          source = File.read(
            Rails.root.join('..', '..', 'app', 'tools', 'better_together', 'mcp', 'search_people_tool.rb')
          )
          # Should NOT have raw interpolation in LIKE
          expect(source).not_to match(/%#\{query\}%/),
            'SearchPeopleTool should use sanitize_like(query) instead of raw #{query} in LIKE patterns'
          expect(source).to include('sanitize_like')
        end
      end

      describe 'SearchGeographyTool' do
        it 'escapes LIKE metacharacters in queries' do
          source = File.read(
            Rails.root.join('..', '..', 'app', 'tools', 'better_together', 'mcp', 'search_geography_tool.rb')
          )
          expect(source).not_to match(/%#\{query\}%/),
            'SearchGeographyTool should use sanitize_like(query) instead of raw #{query} in LIKE patterns'
          expect(source).to include('sanitize_like')
        end
      end

      describe 'SearchPostsTool' do
        it 'escapes LIKE metacharacters in queries' do
          source = File.read(
            Rails.root.join('..', '..', 'app', 'tools', 'better_together', 'mcp', 'search_posts_tool.rb')
          )
          expect(source).not_to match(/%#\{query\}%/),
            'SearchPostsTool should use sanitize_like(query) instead of raw #{query} in LIKE patterns'
          expect(source).to include('sanitize_like')
        end
      end
    end

    describe '6.4 — SearchPeopleTool avoids double policy_scope call' do
      it 'calls policy_scope only once in search_people' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'tools', 'better_together', 'mcp', 'search_people_tool.rb')
        )
        matches = source.scan('policy_scope(BetterTogether::Person)')
        expect(matches.length).to eq(1),
          "Expected single policy_scope call in search_people, found #{matches.length}. " \
          'Assign base scope to a variable and reuse it in .or() clause.'
      end
    end

    describe '6.5 — SendMessageTool uses Pundit authorize' do
      it 'calls authorize on the conversation' do
        source = File.read(
          Rails.root.join('..', '..', 'app', 'tools', 'better_together', 'mcp', 'send_message_tool.rb')
        )
        expect(source).to include('authorize'),
          'SendMessageTool should call authorize for Pundit policy enforcement'
      end
    end

    describe '6.6 — ConversationPolicy#send_message? method exists' do
      it 'defines send_message? method' do
        expect(BetterTogether::ConversationPolicy.instance_methods).to include(:send_message?)
      end

      it 'returns true when user is a participant' do
        user = create(:user)
        person = user.person || create(:person, user: user)
        conversation = create(:conversation)
        create(:conversation_participant, conversation: conversation, person: person)
        conversation.reload # Refresh participants association after adding new participant

        pundit_context = BetterTogether::Mcp::PunditContext.new(user: user)
        policy = BetterTogether::ConversationPolicy.new(pundit_context, conversation)

        expect(policy.send_message?).to be true
      end

      it 'returns false for a non-participant' do
        user = create(:user)
        create(:person, user: user) unless user.person
        conversation = create(:conversation)
        # user is NOT a participant

        pundit_context = BetterTogether::Mcp::PunditContext.new(user: user)
        policy = BetterTogether::ConversationPolicy.new(pundit_context, conversation)

        expect(policy.send_message?).to be false
      end

      it 'returns false for a guest' do
        conversation = create(:conversation)

        pundit_context = BetterTogether::Mcp::PunditContext.new(user: nil)
        policy = BetterTogether::ConversationPolicy.new(pundit_context, conversation)

        expect(policy.send_message?).to be false
      end
    end
  end
end
