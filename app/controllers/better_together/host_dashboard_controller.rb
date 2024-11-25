# frozen_string_literal: true

module BetterTogether
  class HostDashboardController < ApplicationController # rubocop:todo Style/Documentation
    def index # rubocop:todo Metrics/MethodLength
      root_classes = [
        Community, NavigationArea, Page, Platform, Person, Role, ResourcePermission, User,
        Conversation, Message, Category
      ]

      root_classes.each do |klass|
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

      geography_classes = [
        Geography::Continent, Geography::Country, Geography::State, Geography::Region, Geography::Settlement
      ]

      geography_classes.each do |klass|
        # sets @geography_klasses and @geography_klass_count instance variables
        set_resource_variables(klass, prefix: 'geography')
      end
    end

    protected

    def set_resource_variables(klass, prefix: nil)
      variable_name = klass.model_name.name.demodulize.underscore
      instance_variable_set(:"@#{prefix + '_' if prefix}#{variable_name.pluralize}",
                            klass.order(created_at: :desc).limit(3))
      instance_variable_set(:"@#{prefix + '_' if prefix}#{variable_name}_count", klass.count)
    end
  end
end
