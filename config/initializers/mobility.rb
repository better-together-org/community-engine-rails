# frozen_string_literal: true

Mobility.configure do |config|
  # PLUGINS
  config.plugins do
    # Backend
    #
    # Sets the default backend to use in models. This can be overridden in models
    # by passing +backend: ...+ to +translates+.
    #
    # To default to a different backend globally, replace +:key_value+ by another
    # backend name.
    #
    backend :key_value, type: :text

    # ActiveRecord
    #
    # Defines ActiveRecord as ORM, and enables ActiveRecord-specific plugins.
    active_record

    # Accessors
    #
    # Define reader and writer methods for translated attributes. Remove either
    # to disable globally, or pass +reader: false+ or +writer: false+ to
    # +translates+ in any translated model.
    #
    reader
    writer

    # Backend Reader
    #
    # Defines reader to access the backend for any attribute, of the form
    # +<attribute>_backend+.
    #
    backend_reader
    #
    # Or pass an interpolation string to define a different pattern:
    # backend_reader "%s_translations"

    # Query
    #
    # Defines a scope on the model class which allows querying on
    # translated attributes. The default scope is named +i18n+, pass a different
    # name as default to change the global default, or to +translates+ in any
    # model to change it for that model alone.
    #
    query

    # Cache
    #
    # Comment out to disable caching reads and writes.
    #
    cache

    # Dirty
    #
    # Uncomment this line to include and enable globally:
    # dirty
    #
    # Or uncomment this line to include but disable by default, and only enable
    # per model by passing +dirty: true+ to +translates+.
    # dirty false

    # Fallbacks
    #
    # Uncomment line below to enable fallbacks, using +I18n.fallbacks+.
    fallbacks
    #
    # Or uncomment this line to enable fallbacks with a global default.
    # fallbacks { :pt => :en }

    # Presence
    #
    # Converts blank strings to nil on reads and writes. Comment out to
    # disable.
    #
    presence

    # Default
    #
    # Set a default translation per attributes. When enabled, passing +default:
    # 'foo'+ sets a default translation string to show in case no translation is
    # present. Can also be passed a proc.
    #
    # default 'foo'

    # Fallthrough Accessors
    #
    # Uses method_missing to define locale-specific accessor methods like
    # +title_en+, +title_en=+, +title_fr+, +title_fr=+ for each translated
    # attribute. If you know what set of locales you want to support, it's
    # generally better to use Locale Accessors (or both together) since
    # +method_missing+ is very slow.  (You can use both fallthrough and locale
    # accessor plugins together without conflict.)
    #
    # fallthrough_accessors

    # Locale Accessors
    #
    # Uses +def+ to define accessor methods for a set of locales. By default uses
    # +I18n.available_locales+, but you can pass the set of locales with
    # +translates+ and/or set a global default here.
    #
    locale_accessors
    #
    # Or define specific defaults by uncommenting line below
    # locale_accessors [:en, :ja]
  end
end

# Ensure localized attachments backend is loaded and registered early
begin
  require 'mobility/backends/attachments/backend'
rescue LoadError => e
  Rails.logger.debug "Could not require mobility attachments backend: #{e.message}"
end

# Register backend symbol if Mobility exposes the API. Some test bootstraps
# may not have Mobility fully loaded yet; guard registration to avoid raising
# during initializer phases where Mobility isn't loaded.
begin
  if Mobility.respond_to?(:register_backend)
    Mobility.register_backend(:attachments, Mobility::Backends::Attachments)
  else
    Rails.logger.debug 'Mobility does not expose register_backend; skipping attachments backend registration'
  end
rescue StandardError => e
  Rails.logger.debug "Error registering mobility attachments backend: #{e.message}"
end
begin
  require 'mobility/dsl/attachments'
  # Make the DSL available as an extension so models can `extend Mobility::DSL::Attachments`
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.extend Mobility::DSL::Attachments
  end
rescue LoadError => e
  Rails.logger.debug "Could not load Mobility attachments DSL: #{e.message}"
end
