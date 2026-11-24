# frozen_string_literal: true

module BetterTogether
  # Contact details belong to their contactable record. The owner (the person themself, or whoever may
  # update the contactable) writes them. Others read only what the contactable's own visibility and each
  # detail's own privacy allow. Platform roles have no standing right to read private or personal details.
  # Email, phone, social and website policies inherit this; Address overrides its own scope.
  class ContactDetailPolicy < PlatformRecordPolicy
    def create?
      manages_contactable?
    end

    def update?
      manages_contactable?
    end

    def destroy?
      manages_contactable?
    end

    protected

    # The contactable of a ContactDetail, or of a component through its contact detail.
    def contactable
      holder = record.respond_to?(:contactable) ? record : (record.contact_detail if record.respond_to?(:contact_detail))
      holder&.contactable
    end

    def manages_contactable?
      return false unless agent

      target = contactable
      return false if target.nil?
      return manages_person?(target) if target.is_a?(BetterTogether::Person)

      Pundit.policy(user, target)&.update? || false
    end

    # A claimed person owns their details alone. An unclaimed person has no owner, so whoever may update
    # the person record may edit them; reading private rows still follows each detail's own privacy.
    def manages_person?(person)
      return person == agent if person.claimed?

      Pundit.policy(user, person)&.update? || false
    end

    # Contact details are listed only through the visibility of their contactable. Components that carry
    # their own privacy add a row-level rule; the owner sees every row, others only public ones.
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        base = platform_scoped
        return base.where(id: visible_container_ids) unless scope.column_names.include?('privacy')

        owned = base.where(contact_detail_id: owned_container_ids)
        shown = base.where(contact_detail_id: visible_container_ids).where(row_privacy_arel(base.klass.arel_table))
        owned.or(shown)
      end

      protected

      # A public row counts as public only while its platform and community are.
      def effective_public(relation)
        table = relation.klass.arel_table
        relation.where(table[:privacy].eq('public').and(ceiling_open_arel(table)))
      end

      private

      def contact_details = BetterTogether::ContactDetail

      def row_privacy_arel(table)
        shared = effective_community_query(table).and(table[:contact_detail_id].in(member_container_ids.arel))
        effective_public_query(table).or(shared)
      end

      def owned_container_ids
        return contact_details.none.select(:id) unless agent

        own = contact_details.where(contactable_type: 'BetterTogether::Person', contactable_id: agent.id)
        managed = contact_details.where(contactable_type: 'BetterTogether::Community', contactable_id: managed_community_ids)
        own.or(managed).select(:id)
      end

      def member_container_ids
        contact_details.where(contactable_type: 'BetterTogether::Community', contactable_id: member_community_ids)
                       .select(:id)
      end

      def visible_container_ids
        clauses = [person_clause, community_clause] + public_clauses
        clauses.reduce(:or).select(:id)
      end

      def person_clause
        people = BetterTogether::PersonPolicy::Scope.new(user, BetterTogether::Person).resolve
        contact_details.where(contactable_type: 'BetterTogether::Person',
                              contactable_id: people.reorder(nil).select(BetterTogether::Person.arel_table[:id]))
      end

      def community_clause
        contact_details.where(contactable_type: 'BetterTogether::Community',
                              contactable_id: public_ids(BetterTogether::Community))
                       .or(contact_details.where(contactable_type: 'BetterTogether::Community',
                                                 contactable_id: member_community_ids))
      end

      # Other contactables are listed when they are effectively public; unknown types stay hidden.
      def public_clauses
        %w[Infrastructure::Building Infrastructure::Floor Infrastructure::Room].map do |name|
          type = "BetterTogether::#{name}"
          contact_details.where(contactable_type: type, contactable_id: public_ids(type.constantize))
        end
      end

      def public_ids(model)
        return model.none.select(:id) unless model.column_names.include?('privacy')

        table = model.arel_table
        rows = model.where(table[:privacy].eq('public'))
        rows = rows.where(Arel::Nodes::Grouping.new(model.privacy_ceiling_open_arel(table))) if
          model.respond_to?(:privacy_ceiling_open_arel)
        rows.select(:id)
      end

      def member_community_ids
        return [] unless agent

        @member_community_ids ||= agent.person_community_memberships.active.pluck(:joinable_id)
      end

      def managed_community_ids
        BetterTogether::Community.where(id: member_community_ids).select do |community|
          BetterTogether::CommunityPolicy.new(user, community).update?
        end.map(&:id)
      end
    end
  end
end
