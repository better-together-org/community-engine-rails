# frozen_string_literal: true

module BetterTogether
  class HostDashboardController < ApplicationController # rubocop:todo Style/Documentation
    def index # rubocop:todo Metrics/MethodLength
      authorize [:host_dashboard], :show?, policy_class: HostDashboardPolicy

      root_classes = [
        Community, NavigationArea, Page, Platform, Person, Role, ResourcePermission, User,
        Conversation, Message, Category
      ]

      root_classes.each do |klass|
        # sets @klasses and @klass_count instance variables
        set_resource_variables(klass)
      end

      engagement_classes = [
        Post, Comment, CallForInterest
      ]

      engagement_classes.each do |klass|
        # sets @engagement_klasses and @engagement_klass_count instance variables
        set_resource_variables(klass, prefix: 'engagement')
      end

      exchange_classes = [
        Joatu::Offer, Joatu::Request, Joatu::Agreement, Joatu::Category, Joatu::ResponseLink
      ]

      exchange_classes.each do |klass|
        # sets @exchange_klasses and @exchange_klass_count instance variables
        set_resource_variables(klass, prefix: 'exchange')
      end

      event_classes = [
        Event, EventInvitation, EventAttendance, Calendar, CalendarEntry
      ]

      event_classes.each do |klass|
        # sets @klasses and @klass_count instance variables
        set_resource_variables(klass)
      end

      content_classes = [
        Content::Block
      ]

      content_classes.each do |klass|
        # sets @content_klasses and @content_klass_count instance variables
        set_resource_variables(klass, prefix: 'content')
      end

      Content::Block.load_all_subclasses
      content_block_types = Content::Block.descendants.sort_by { |klass| klass.model_name.human }
      content_block_types.each do |klass|
        # sets @content_klasses and @content_klass_count instance variables
        set_resource_variables(klass, prefix: 'content')
      end

      @content_block_type_cards = content_block_types.map do |klass|
        variable_name = klass.model_name.name.demodulize.underscore

        {
          model_class: klass,
          collection: instance_variable_get(:"@content_#{variable_name.pluralize}"),
          count: instance_variable_get(:"@content_#{variable_name}_count"),
          index_url: helpers.content_blocks_path,
          link_index: true,
          link_resources: false
        }
      end

      geography_classes = [
        Geography::Continent, Geography::Country, Geography::State, Geography::Region, Geography::Settlement,
        Geography::Map, Geography::Space
      ]

      geography_classes.each do |klass|
        # sets @geography_klasses and @geography_klass_count instance variables
        set_resource_variables(klass, prefix: 'geography')
      end

      infrastructure_classes = [
        Infrastructure::Building, Infrastructure::Floor, Infrastructure::Room
      ]

      infrastructure_classes.each do |klass|
        # sets @infrastructure_klasses and @infrastructure_klass_count instance variables
        set_resource_variables(klass, prefix: 'infrastructure')
      end
    end

    protected

    def set_resource_variables(klass, prefix: nil)
      variable_name = klass.model_name.name.demodulize.underscore
      instance_variable_set(:"@#{"#{prefix}_" if prefix}#{variable_name.pluralize}",
                            klass.order(created_at: :desc).limit(3))
      instance_variable_set(:"@#{"#{prefix}_" if prefix}#{variable_name}_count", klass.count)
    end
  end
end
