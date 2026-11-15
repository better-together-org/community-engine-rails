# frozen_string_literal: true

module BetterTogether
  # Facilitates building forms by pulling out reusable components and logic
  module FormHelper # rubocop:todo Metrics/ModuleLength
    def class_field_required(klass, field)
      klass.validators_on(field).any? { |v| v.kind == :presence }
    end

    # rubocop:todo Metrics/MethodLength
    # `required:`/`prompt:` are overridable so an inline nested address form (event
    # location picker) can render the label select without a blank prompt option
    # that a browser `required` check would otherwise block on.
    def label_select_field(form, required: true, prompt: 'Select Label') # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # rubocop:todo-next Metrics/BlockLength
      content_tag(:div, class: 'label-select', data: { controller: 'better_together--dependent-fields' }) do
        label_select_id = dom_id(form.object, :label).split('-').first

        # `for:` must match the select's overridden id below, or the select has no
        # accessible name (axe select-name).
        field_label = required_label(
          form,
          :label,
          class: 'form-label',
          for: label_select_id
        )

        select_field = form.select(
          :select_label,
          form.object.class.label_options,
          { prompt: prompt, required: required },
          class: 'form-select',
          id: label_select_id,
          'data-better_together--dependent-fields-target' => 'controlField'
        )

        other_text_field = content_tag(
          :div,
          class: "other-label #{dom_class(form.object, :label_text_field)}",
          data: {
            'dependent-fields-control' => label_select_id
          },
          'data-better_together--dependent-fields-target' => 'dependentField',
          "data-show-if-control_#{label_select_id}" => 'other'
        ) do
          form.text_field(
            :text_label,
            class: 'form-control mt-3',
            placeholder: t('better_together.labelable.custom-label-placeholder')
          )
        end

        field_label + select_field + other_text_field
      end
    end
    # rubocop:enable Metrics/MethodLength

    def language_select_field(form: nil, field_name: :locale, selected_locale: I18n.locale, options: {},
                              html_options: {})
      # Merge default options with the provided options
      default_options = { prompt: t('helpers.language_select.prompt') }
      merged_options = default_options.merge(options)
      selected_locale ||= I18n.locale

      # Merge default HTML options with the provided HTML options
      default_html_options = { class: 'form-select', required: true }
      merged_html_options = default_html_options.merge(html_options)

      if form
        form.select(field_name, locale_options_for_select(selected_locale), merged_options, merged_html_options)
      else
        select_tag(field_name, locale_options_for_select(selected_locale), merged_html_options.merge(merged_options))
      end
    end

    def locale_options_for_select(selected_locale = I18n.locale)
      options_for_select(
        I18n.available_locales.map { |locale| [I18n.t("locales.#{locale}", locale:), locale] },
        selected_locale
      )
    end

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/ParameterLists
    def localized_datetime_field(field:, form: nil, label_text: nil, hint_text: nil, include_time: true,
                                 selected_value: nil, generate_label: true, **options)
      # rubocop:enable Metrics/ParameterLists
      # Determine the datetime format based on the locale and whether time should be included
      include_time ? I18n.t('time.formats.datetime_picker') : I18n.t('time.formats.date_picker')

      content_tag(:div, class: 'mb-3') do
        # Add label if provided and generate_label is true
        if generate_label
          label_html = if form
                         form.label(field, label_text,
                                    class: 'form-label')
                       else
                         label_tag(field, label_text, class: 'form-label')
                       end
          concat(label_html) if label_text
        end

        # Determine the field type (form or standalone)
        if form
          concat form.datetime_field(field, { class: 'form-control', value: selected_value }.merge(options))
        else
          concat datetime_field_tag(field, selected_value, { class: 'form-control' }.merge(options))
        end

        # Add hint text if provided
        concat content_tag(:small, hint_text, class: 'form-text text-muted') if hint_text
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    PRIVACY_ORDER = %w[private community public].freeze

    # Every privacy level stays selectable: a platform or community ceiling
    # only limits who can see the record today, never what may be saved.
    def privacy_field(form:, klass:, html_options: {})
      select_opts = build_privacy_select_options(klass, form.object.privacy)
      form.select :privacy, select_opts, {}, build_privacy_html_options(html_options)
    end

    # Most open level the wrapping platform and community currently allow
    # ('public' when neither restricts), matching PrivacyCeilingValidatable.
    def max_allowed_privacy(platform:, community:)
      BetterTogether::PrivacyCeilingValidatable.ceiling_for(platform:, community:) || PRIVACY_ORDER.last
    end
    # Deprecated alias kept for host-app view overrides written against the Post-specific name.
    alias max_allowed_post_privacy max_allowed_privacy

    # Non-blocking warning shown beside a privacy select when the platform or
    # community would hide a public record from non-members.
    def privacy_ceiling_notice(record, platform: record.try(:platform) || Current.platform, community: record.try(:community))
      ceiling = max_allowed_privacy(platform:, community:)
      return if ceiling == PRIVACY_ORDER.last

      source = platform.present? && !platform.privacy_public? ? 'platform' : 'community'
      level = t("attributes.privacy_list.#{ceiling}", default: ceiling.humanize)
      content_tag(:div, id: dom_id(record, :privacy_ceiling_notice), role: 'note',
                        class: 'alert alert-warning small mt-2 mb-0 py-2',
                        data: { privacy_ceiling: ceiling, privacy_ceiling_source: source }) do
        concat content_tag(:i, '', class: 'fa-solid fa-triangle-exclamation me-1', 'aria-hidden': true)
        concat t("better_together.privacy.ceiling_notice.#{source}", level: level)
      end
    end

    private

    def build_privacy_select_options(klass, selected)
      options = klass.privacies.keys.map { |key| [key.humanize, key] }
      options_for_select(options, selected)
    end

    def build_privacy_html_options(html_options)
      opts = { class: 'form-select', required: true }
      return opts.merge(html_options.except(:class)) unless html_options[:class].present?

      opts[:class] = "#{opts[:class]} #{html_options[:class]}".strip
      opts.merge(html_options.except(:class))
    end

    def build_federation_visibility_html_options(html_options, field_id)
      opts = { class: 'form-select', id: field_id }
      return opts.merge(html_options.except(:class, :id)) unless html_options[:class].present?

      opts[:class] = "#{opts[:class]} #{html_options[:class]}".strip
      opts.merge(html_options.except(:class, :id))
    end

    def federation_visibility_label
      t('better_together.federatable.labels.federation_visibility', default: 'Federation visibility')
    end

    def federation_visibility_hint
      t('better_together.federatable.hints.federation_visibility',
        default: "Override this platform's federation settings for this specific item. " \
                 '"Use platform default" follows your account-wide federation preference ' \
                 "and each connection's content-sharing settings.")
    end

    def federation_visibility_select_options(record)
      options_for_select(
        record.class.translated_federation_visibilities.map { |label, key, _value| [label, key] },
        record.federation_visibility
      )
    end

    def federation_content_grants_label
      t('better_together.federatable.labels.federation_content_grants', default: 'Federation per connection')
    end

    def federation_content_grants_hint
      t('better_together.federatable.hints.federation_content_grants',
        default: 'Override federation for this item on one specific connection, without changing ' \
                 'the general federation visibility above.')
    end

    def federation_content_grant_status_options(record, connection)
      keys = %w[platform_default allowed denied]
      labels = {
        'platform_default' => t('better_together.federatable.grant_statuses.platform_default',
                                default: 'Use platform default'),
        'allowed' => t('better_together.federatable.grant_statuses.allowed', default: 'Always federate'),
        'denied' => t('better_together.federatable.grant_statuses.denied', default: 'Never federate')
      }
      current = record.federation_grant_status_for(connection) || 'platform_default'
      options_for_select(keys.map { |key| [labels[key], key] }, current)
    end

    def federation_content_grant_row(form:, record:, connection:)
      field_id = "#{dom_id(record)}_federation_content_grant_#{connection.id}"
      field_name = "#{form.object_name}[federation_content_grants_by_connection][#{connection.id}]"

      content_tag(:div, class: 'row g-2 align-items-center mb-1',
                        id: "federation-content-grant-#{connection.id}") do
        concat content_tag(:label, connection.to_s, for: field_id, class: 'col-6 col-md-4 small mb-0')
        concat(content_tag(:div, class: 'col-6 col-md-4') do
          select_tag(
            field_name,
            federation_content_grant_status_options(record, connection),
            id: field_id, class: 'form-select form-select-sm'
          )
        end)
      end
    end

    public

    def contributor_display_visibility_field(form:, include_inherit:, label:, hint:, html_options: {})
      values = contributor_display_visibility_values(include_inherit:)
      options = contributor_display_visibility_html_options(html_options)
      # `form_with` does not auto-generate id/for pairs in this app, so build an explicit,
      # stable id to keep the <select> an accessible, labelled form control (WCAG select-name).
      field_id = options[:id] || "#{dom_id(form.object)}_contributors_display_visibility"
      options = options.merge(id: field_id)

      content_tag(:div) do
        concat form.label(:contributors_display_visibility, label, for: field_id)
        concat form.select(
          :contributors_display_visibility,
          contributor_display_visibility_select_options(form:, values:),
          {},
          options
        )
        concat content_tag(:small, hint, class: 'form-text text-muted mt-2')
      end
    end

    def federation_visibility_field(form:, html_options: {})
      # `form_with` does not auto-generate id/for pairs in this app, so build an explicit,
      # stable id to keep the <select> an accessible, labelled form control (WCAG select-name).
      field_id = html_options[:id] || "#{dom_id(form.object)}_federation_visibility"

      content_tag(:div, class: 'mb-3') do
        concat form.label(:federation_visibility, federation_visibility_label, for: field_id, class: 'form-label')
        concat form.select(
          :federation_visibility,
          federation_visibility_select_options(form.object),
          {},
          build_federation_visibility_html_options(html_options, field_id)
        )
        concat content_tag(:small, federation_visibility_hint, class: 'form-text text-muted mt-1')
      end
    end

    # Per-connection federation override -- one row per active connection that
    # already allows this record's content type (connection-level content-type
    # gating stays authoritative; this can only narrow or widen federation for
    # a specific connection, never bypass it). `connections` must be
    # pre-computed by the caller (see _balance_card.html.erb convention) to
    # avoid an N+1 query per rendered item.
    def federation_content_grants_field(form:, record:, connections:)
      return if connections.blank?

      content_tag(:div, class: 'mb-3', id: "#{dom_id(record)}_federation_content_grants") do
        concat content_tag(:span, federation_content_grants_label, class: 'form-label d-block')
        concat content_tag(:small, federation_content_grants_hint, class: 'form-text text-muted d-block mb-2')
        connections.each { |connection| concat federation_content_grant_row(form:, record:, connection:) }
      end
    end

    # Active connections eligible for a per-connection grant on this record --
    # the connection-level content-type toggle (allows_content_type?) already
    # gates eligibility one layer up, so only connections that allow this
    # record's content type are worth offering a per-connection override for.
    def federation_connections_for(record)
      ::BetterTogether::PlatformConnection.active.select do |connection|
        connection.allows_content_type?(record.federation_content_type_key)
      end
    end

    # `form` here is the nested comment_config fields_for builder (form.fields_for
    # :comment_config, commentable.comment_config || commentable.build_comment_config
    # in the calling view — mirrors _recurrence_fields.html.erb's fields_for wrapping,
    # since this is a separate polymorphic model, not a direct attribute on commentable).
    def comment_permission_field(form:, commentable:)
      comment_settings_select_field(
        form:, commentable:, attribute: :permission,
        values: BetterTogether::CommentConfig.permissions.keys,
        translation_scope: 'better_together.comment_config.permission_options',
        label: t('better_together.comment_config.labels.permission', default: 'Who can comment'),
        hint: t('better_together.comment_config.hints.permission',
                default: 'Controls who is allowed to post new comments.')
      )
    end

    def comment_visibility_field(form:, commentable:)
      comment_settings_select_field(
        form:, commentable:, attribute: :visibility,
        values: BetterTogether::CommentConfig.visibilities.keys,
        translation_scope: 'better_together.comment_config.visibility_options',
        label: t('better_together.comment_config.labels.visibility', default: 'Who can see comments'),
        hint: t('better_together.comment_config.hints.visibility',
                default: 'Controls who can see the comment thread.')
      )
    end

    private

    def comment_settings_select_field(form:, commentable:, attribute:, values:, translation_scope:, label:, hint:) # rubocop:todo Metrics/ParameterLists
      field_id = "#{dom_id(commentable)}_comment_#{attribute}"
      selected = form.object.public_send(attribute)

      content_tag(:div, class: 'mb-2') do
        concat form.label(attribute, label, for: field_id, class: 'form-label')
        concat form.select(
          attribute,
          options_for_select(values.map { |v| [t("#{translation_scope}.#{v}"), v] }, selected),
          {},
          { class: 'form-select', id: field_id }
        )
        concat content_tag(:small, hint, class: 'form-text text-muted mt-1')
      end
    end

    public

    # rubocop:todo Metrics/MethodLength
    # Accepts an optional label_text override which, when provided, will be used
    # instead of the model's human_attribute_name for the field. This is useful
    # when the visible label needs to be different from the translated attribute
    # name (for example: participant_ids -> "Add participants").
    # rubocop:todo-next Metrics/PerceivedComplexity
    def required_label(form_or_object, field, label_text: nil, **options) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      # Determine if it's a form object or just an object
      if form_or_object.respond_to?(:object)
        object = form_or_object.object
        # Use provided label_text override if present, otherwise fall back to translation
        label_text ||= object.class.human_attribute_name(field)
        class_name = options.delete(:class_name)

        # Use the provided class_name for validation check if present, otherwise use the object's class
      else
        object = form_or_object
        label_text ||= object.class.human_attribute_name(field)

        # Use the provided class_name for validation check if present, otherwise use the object's class
      end

      klass = class_name ? class_name.constantize : object.class
      is_required = class_field_required(klass, field)

      # Append asterisk for required fields and attach tooltip to the asterisk
      if is_required
        tooltip_text = I18n.t('helpers.required_info', default: 'This field is required')
        # Make the asterisk keyboard-focusable and allow the tooltip to be
        # triggered by click as well as hover/focus so it works on mobile.
        asterisk = content_tag(:span, '*', class: 'required-indicator', tabindex: 0, role: 'button',
                                           data: { bs_toggle: 'tooltip', bs_trigger: 'hover focus click' },
                                           title: tooltip_text)
        label_text += " #{asterisk}"
      end

      if form_or_object.respond_to?(:label)
        label_html = form_or_object.label(field, label_text.html_safe, options)
        # Some test doubles return an empty string for label; fall back to
        # `label_tag` to ensure the markup exists in view specs.
        return label_tag(field, label_text.html_safe, options) if label_html.nil? || label_html.to_s.strip.empty?

        label_html
      else
        label_tag(field, label_text.html_safe, options)
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Metrics/ParameterLists
    def type_select_field(form:, model_class:, selected_type: nil, include_model_class: false, include_blank: true,
                          **options)
      # rubocop:enable Metrics/ParameterLists
      # Determine if the model is persisted
      disabled = form&.object&.persisted? || false

      options = {
        required: true,
        class: 'form-select',
        data: { controller: 'better_together--slim-select' },
        disabled:, # Disable if the model is persisted
        **options
      }

      descendants = model_class.descendants.map { |descendant| [descendant.model_name.human, descendant.name] }

      dropdown_values = if include_model_class
                          [[model_class.model_name.human, model_class.name]] + descendants
                        else
                          descendants
                        end

      if form
        form.select :type, options_for_select(dropdown_values, form.object.type), { include_blank: }, options
      else
        select_tag 'type', options_for_select(dropdown_values, selected_type),
                   { include_blank: }.merge(options)
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength

    # Generates a role selection field for invitations
    # @param form [ActionView::Helpers::FormBuilder] The form builder instance
    # @param field_name [Symbol] The name of the field (typically :role_id)
    # @param resource_type [String] The resource type to filter roles by (e.g., 'BetterTogether::Community')
    # @param prompt [String, nil] The prompt text for the select field
    # @param html_options [Hash] Additional HTML options for the select field
    # @return [String] HTML for the role selection field
    def role_select_field(form:, field_name:, resource_type:, html_options: {})
      roles = BetterTogether::Role.where(resource_type: resource_type)
                                  .includes(:string_translations)
                                  .order(:position)
                                  .i18n
      html_opts = { class: 'form-select', name: "invitation[#{field_name}]" }.merge(html_options)

      form.collection_select(field_name, roles, :id, :name, {}, html_opts)
    end

    private

    def contributor_display_visibility_values(include_inherit:)
      if include_inherit
        BetterTogether::Authorable::CONTRIBUTOR_DISPLAY_VISIBILITIES
      else
        BetterTogether::Authorable::EFFECTIVE_CONTRIBUTOR_DISPLAY_VISIBILITIES
      end
    end

    def contributor_display_visibility_html_options(html_options)
      options = { class: 'form-select' }
      return options.merge(html_options) unless html_options[:class].present?

      options[:class] = "#{options[:class]} #{html_options[:class]}".strip
      options.merge(html_options.except(:class))
    end

    def contributor_display_visibility_select_options(form:, values:)
      selected_value = if form.object.respond_to?(:contributors_display_visibility)
                         form.object.contributors_display_visibility
                       end

      options_for_select(
        values.map do |value|
          [t("better_together.authorable_contributor_visibility.options.#{value}"), value]
        end,
        selected_value
      )
    end
  end
end
