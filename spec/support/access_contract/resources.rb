# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength

module AccessContractProbe
  # One probe per contract resource. Each declares its actions, builds its fixture
  # records, and says which persona and state pairs can occur together.
  module Resources
    def self.build(world)
      [CommunityProbe, MembershipProbe, InvitationProbe, PersonProbe, BlockProbe, ContactDetailProbe, JoatuOfferProbe,
       JoatuRequestProbe, *BILLING_PROBES]
        .to_h do |klass|
        probe = klass.new(world)
        [probe.key, probe]
      end
    end

    # Shared behaviour. Subclasses define KEY, POLICY, MODEL, ACTIONS and the fixture builders.
    class Base
      include FactoryBot::Syntax::Methods

      attr_reader :world

      def initialize(world)
        @world = world
        build_fixtures
      end

      def key = self.class::KEY
      def actions = self.class::ACTIONS

      def evaluate(action, persona, state)
        return 'na' unless applicable?(persona, state)

        actor = actor_for(persona, state)
        spec = actions.fetch(action)
        spec == :scope ? scope_result(actor, state) : policy_result(actor, spec, state)
      rescue StandardError => e
        "error:#{e.class.name.demodulize}"
      end

      private

      def policy_class = self.class::POLICY.constantize
      def model_class = self.class::MODEL.constantize

      def policy_result(actor, spec, state)
        method, target = spec
        record = target == :class ? model_class : record_for(target, state)
        policy_class.new(actor, record).public_send(method) ? 'allow' : 'deny'
      end

      def scope_result(actor, state)
        resolved = policy_class::Scope.new(actor, model_class).resolve
        resolved.where(id: record_for(:subject, state).id).exists? ? 'allow' : 'deny'
      end

      def actor_for(persona, state)
        persona == 'record_owner' ? owner_for(state) : world.user_for(persona)
      end

      # Class-level and create checks have no record, so owner personas cannot occur there.
      def applicable?(persona, state)
        return false if %w[any new].include?(state) && %w[record_owner blocked_user].include?(persona)

        true
      end

      def make_privacy(record, privacy)
        record.update_columns(privacy:)
        record.reload
      end
    end

    # Communities in each privacy state, all created by the same owner.
    class CommunityProbe < Base
      KEY = 'community'
      POLICY = 'BetterTogether::CommunityPolicy'
      MODEL = 'BetterTogether::Community'
      ACTIONS = {
        'index' => %i[index? class], 'show' => %i[show? subject], 'create' => %i[create? new],
        'update' => %i[update? subject], 'destroy' => %i[destroy? subject],
        'manage_integrations' => %i[manage_integrations? subject], 'create_events' => %i[create_events? subject],
        'view_members' => %i[view_members? subject], 'manage_roles' => %i[manage_roles? subject],
        'view_quota_usage' => %i[view_quota_usage? subject], 'download' => %i[download? subject],
        'suspend' => %i[suspend? subject], 'quarantine' => %i[quarantine? subject], 'hide' => %i[hide? subject],
        'scope' => :scope
      }.freeze

      def record_for(target, state)
        return BetterTogether::Community.new if target == :new

        @communities.fetch(state)
      end

      def owner_for(_state) = @owner

      private

      def build_fixtures
        @owner = world.new_user
        @communities = %w[public community private].to_h do |privacy|
          community = create(:better_together_community, creator: @owner.person, privacy: 'private')
          make_privacy(community, privacy)
          world.join_personas(community)
          [privacy, community]
        end
      end
    end

    # A private community with one target member; "own" is the target's own membership.
    class MembershipProbe < Base
      KEY = 'person_community_membership'
      POLICY = 'BetterTogether::PersonCommunityMembershipPolicy'
      MODEL = 'BetterTogether::PersonCommunityMembership'
      ACTIONS = {
        'index' => %i[index? class], 'show' => %i[show? subject], 'create' => %i[create? new],
        'edit' => %i[edit? subject], 'destroy' => %i[destroy? subject], 'scope' => :scope
      }.freeze

      def record_for(target, _state)
        return @membership unless target == :new

        BetterTogether::PersonCommunityMembership.new(joinable: @community, member: @target.person, role: @membership.role)
      end

      def owner_for(_state) = @target

      private

      def build_fixtures
        @community = create(:better_together_community, creator: world.new_user.person, privacy: 'private')
        world.join_personas(@community)
        @target = world.new_user
        @membership = world.join(@community, @target.person, 'community_member')
      end

      def applicable?(persona, state)
        return false if persona == 'blocked_user'
        return persona == 'record_owner' if state == 'own'
        return persona != 'record_owner' if state == 'someone_elses'

        persona != 'record_owner'
      end
    end

    # A pending invitation to a private community; "own" is the inviter.
    class InvitationProbe < Base
      KEY = 'community_invitation'
      POLICY = 'BetterTogether::CommunityInvitationPolicy'
      MODEL = 'BetterTogether::CommunityInvitation'
      ACTIONS = {
        'index' => %i[index? class], 'show' => %i[show? subject], 'create' => %i[create? subject],
        'destroy' => %i[destroy? subject], 'resend' => %i[resend? subject], 'scope' => :scope
      }.freeze

      def record_for(_target, _state) = @invitation
      def owner_for(_state) = @inviter

      private

      def build_fixtures
        @community = create(:better_together_community, creator: world.new_user.person, privacy: 'private')
        world.join_personas(@community)
        @inviter = world.new_user
        @invitation = create(:better_together_community_invitation, invitable: @community, inviter: @inviter.person,
                                                                    status: 'pending')
      end

      def applicable?(persona, state)
        return false if persona == 'blocked_user'
        return persona == 'record_owner' if state == 'own'
        return persona != 'record_owner' if state == 'someone_elses'

        persona != 'record_owner'
      end
    end

    # People in each privacy state, all members of one shared community with the community personas.
    class PersonProbe < Base
      KEY = 'person'
      POLICY = 'BetterTogether::PersonPolicy'
      MODEL = 'BetterTogether::Person'
      ACTIONS = {
        'index' => %i[index? class], 'show' => %i[show? subject], 'create' => %i[create? new],
        'update' => %i[update? subject], 'destroy' => %i[destroy? subject], 'download' => %i[download? subject],
        'suspend' => %i[suspend? subject], 'restore' => %i[restore? subject], 'scope' => :scope
      }.freeze

      attr_reader :subjects

      def record_for(target, state)
        return BetterTogether::Person.new if target == :new
        return @unclaimed if state == 'unclaimed'

        @subjects.fetch(state).person
      end

      def owner_for(state) = @subjects.fetch(state)

      private

      def build_fixtures
        @shared = create(:better_together_community, creator: world.new_user.person, privacy: 'private')
        world.join_personas(@shared)
        # A claimed profile has a confirmed user; its fixture is a public profile.
        @subjects = %w[public community private claimed].to_h do |state|
          privacy = state == 'claimed' ? 'public' : state
          user = world.new_user
          make_privacy(user.person, privacy)
          world.join(@shared, user.person, 'community_member')
          BetterTogether::PersonBlock.create!(blocker: user.person, blocked: world.user_for('blocked_user').person,
                                              platform: world.host)
          [state, user]
        end
        @unclaimed = make_privacy(create(:better_together_person), 'public')
      end

      def applicable?(persona, state)
        return false if state == 'unclaimed' && persona == 'record_owner'

        super
      end
    end

    # A block placed by the target person; "own" is the blocker, "blocked_user" is the blocked person.
    class BlockProbe < Base
      KEY = 'person_block'
      POLICY = 'BetterTogether::PersonBlockPolicy'
      MODEL = 'BetterTogether::PersonBlock'
      ACTIONS = {
        'index' => %i[index? class], 'show' => %i[show? subject], 'create' => %i[create? new],
        'destroy' => %i[destroy? subject], 'scope' => :scope
      }.freeze

      def record_for(target, _state)
        return @block unless target == :new

        BetterTogether::PersonBlock.new(blocker: @blocker.person, blocked: @blocked.person, platform: world.host)
      end

      def owner_for(_state) = @blocker

      private

      def build_fixtures
        @blocker = world.new_user
        @blocked = world.user_for('blocked_user')
        @block = BetterTogether::PersonBlock.create!(blocker: @blocker.person, blocked: @blocked.person, platform: world.host)
      end

      def applicable?(persona, state)
        return persona == 'record_owner' if state == 'own'
        return true if %w[any new].include?(state) && persona != 'record_owner'

        persona != 'record_owner'
      end
    end

    # Joatu records in each privacy state, all created by one owner who has blocked the blocked_user persona.
    # Community personas are plain platform members here: Joatu is platform scoped, not community scoped.
    class JoatuBase < Base
      def owner_for(_state) = @owner

      def record_for(target, state)
        return self.class::MODEL.constantize.new(creator: @owner.person, platform: world.host) if target == :new

        @records.fetch(state)
      end

      private

      def build_fixtures
        @owner = world.new_user
        BetterTogether::PersonBlock.create!(blocker: @owner.person, blocked: world.user_for('blocked_user').person,
                                            platform: world.host)
        @records = %w[public community private].to_h do |privacy|
          record = create(self.class::FACTORY, creator: @owner.person, privacy: 'private', platform: world.host)
          [privacy, make_privacy(record, privacy)]
        end
      end
    end

    class JoatuOfferProbe < JoatuBase
      KEY = 'joatu_offer'
      POLICY = 'BetterTogether::Joatu::OfferPolicy'
      MODEL = 'BetterTogether::Joatu::Offer'
      FACTORY = :better_together_joatu_offer
      ACTIONS = {
        'index' => %i[index? class], 'show' => %i[show? subject], 'create' => %i[create? new],
        'update' => %i[update? subject], 'destroy' => %i[destroy? subject],
        'respond_with_request' => %i[respond_with_request? subject], 'scope' => :scope
      }.freeze
    end

    class JoatuRequestProbe < JoatuBase
      KEY = 'joatu_request'
      POLICY = 'BetterTogether::Joatu::RequestPolicy'
      MODEL = 'BetterTogether::Joatu::Request'
      FACTORY = :better_together_joatu_request
      ACTIONS = {
        'index' => %i[index? class], 'show' => %i[show? subject], 'create' => %i[create? new],
        'update' => %i[update? subject], 'destroy' => %i[destroy? subject],
        'respond_with_offer' => %i[respond_with_offer? subject], 'scope' => :scope
      }.freeze
    end

    # The contact detail of a public person and of a private person.
    class ContactDetailProbe < Base
      KEY = 'contact_detail'
      POLICY = 'BetterTogether::ContactDetailPolicy'
      MODEL = 'BetterTogether::ContactDetail'
      ACTIONS = {
        'show' => %i[show? subject], 'create' => %i[create? new], 'update' => %i[update? subject],
        'destroy' => %i[destroy? subject], 'scope' => :scope
      }.freeze

      def record_for(target, state)
        return BetterTogether::ContactDetail.new(contactable: @details.fetch(state).contactable) if target == :new

        @details.fetch(state)
      end

      def owner_for(state) = @owners.fetch(state)

      def applicable?(persona, state)
        return false if state == 'unclaimed' && persona == 'record_owner'

        super
      end

      private

      def build_fixtures
        @owners = %w[public private].to_h do |privacy|
          user = world.new_user
          make_privacy(user.person, privacy)
          [privacy, user]
        end
        @details = @owners.transform_values { |user| user.person.contact_detail }
        unclaimed = make_privacy(create(:better_together_person), 'public')
        @details['unclaimed'] = unclaimed.contact_detail.reload
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength
