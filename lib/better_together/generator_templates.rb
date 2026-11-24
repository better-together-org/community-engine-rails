# frozen_string_literal: true

module BetterTogether
  # Makes the stock ActiveRecord generators search lib/templates of the host app and of
  # this engine, even when the generator classes were loaded before the paths were known.
  module GeneratorTemplates
    GENERATORS = {
      'migration' => 'ActiveRecord::Generators::MigrationGenerator',
      'model' => 'ActiveRecord::Generators::ModelGenerator'
    }.freeze

    def self.register(template_roots)
      load_generators
      GENERATORS.each do |name, class_name|
        add_paths(class_name.constantize, name, Array(template_roots))
      end
    end

    def self.load_generators
      require 'rails/generators'
      # Generator class options read Rails::Generators.options when the class loads.
      Rails::Generators.configure!(Rails.application.config.generators)
      require 'rails/generators/active_record/migration/migration_generator'
      require 'rails/generators/active_record/model/model_generator'
    end

    def self.add_paths(klass, name, roots)
      roots.each do |root|
        dir = File.join(root.to_s, 'active_record', name)
        klass.source_paths << dir unless klass.source_paths.include?(dir)
      end
    end
  end
end
