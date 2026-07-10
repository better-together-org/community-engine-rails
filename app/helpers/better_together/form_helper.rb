# frozen_string_literal: true

module BetterTogether
  # Facilitates building forms by pulling out reusable components and logic
  module FormHelper # rubocop:todo Metrics/ModuleLength
    def class_field_required(klass, field)
      klass.validators_on(field).any? { |v| v.kind == :presence }
    end

    # rubocop:todo Metrics/MethodLength
    def label_select_field(form) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # rubocop:todo Metrics/BlockLength
      content_tag(:div, class: 'label-select', data: { controller: 'better_together--dependent-fields' }) do
        field_label = required_label(
          form,
          :label,
          class: 'form-label'
        )

        label_select_id = dom_id(form.object, :label).split('-').first
        select_field = form.select(
          :select_label,
          form.object.class.label_options,
          { prompt: 'Select Label', required: true },
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
      # rubocop:enable Metrics/BlockLength
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

    # Ordered from most restrictive to most open — used to compute the ceiling
    # privacy a privacy-scoped record may have given its platform and
    # community context.
    PRIVACY_ORDER = %w[private community public].freeze

    def privacy_field(form:, klass:, html_options: {}, max_privacy: nil)
      select_opts = build_privacy_select_options(klass, max_privacy, form.object.privacy)
      form.select :privacy, select_opts, {}, build_privacy_html_options(html_options)
    end

    # Returns the most open privacy level a record may carry given its
    # wrapping platform and community.  Rules:
    #   - Platform non-public  → ceiling is platform privacy
    #   - Platform public + community non-public → ceiling is 'community'
    #     (members of a private/community community can still see community-level content)
    #   - Platform public + community public → ceiling is 'public'
    def max_allowed_privacy(platform:, community:)
      platform_level = PRIVACY_ORDER.index(platform&.privacy) || (PRIVACY_ORDER.length - 1)
      community_level = community_privacy_max_level(community)
      PRIVACY_ORDER[[platform_level, community_level].min]
    end
    # Deprecated alias kept for compatibility with any host-app view overrides
    # written against the Post-specific name before this helper was generalized.
    alias max_allowed_post_privacy max_allowed_privacy

    # Returns a translated hint string when privacy options are constrained,
    # or nil when there is no restriction (all options open).
    def privacy_constraint_hint(platform:, community:)
      if platform.present? && !platform.privacy_public?
        t('better_together.privacy.hints.privacy_limited_by_platform')
      elsif community.present? && !community.privacy_public?
        t('better_together.privacy.hints.privacy_limited_by_community')
      end
    end

    private

    def community_privacy_max_level(community)
      return PRIVACY_ORDER.length - 1 unless community

      # A public community allows public posts; any other community privacy
      # (community or private) caps post visibility at 'community'.
      community.privacy_public? ? PRIVACY_ORDER.length - 1 : PRIVACY_ORDER.index('community')
    end

    def build_privacy_select_options(klass, max_privacy, selected)
      max_level = max_privacy ? PRIVACY_ORDER.index(max_privacy) : PRIVACY_ORDER.length - 1
      options = klass.privacies.keys.map do |key|
        level = PRIVACY_ORDER.index(key) || 0
        [key.humanize, key, level > max_level ? { disabled: true } : {}]
      end
      options_for_select(options, selected)
    end

    def build_privacy_html_options(html_options)
      opts = { class: 'form-select', required: true }
      return opts.merge(html_options.except(:class)) unless html_options[:class].present?

      opts[:class] = "#{opts[:class]} #{html_options[:class]}".strip
      opts.merge(html_options.except(:class))
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
    # rubocop:todo Metrics/PerceivedComplexity
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
    # rubocop:enable Metrics/PerceivedComplexity
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
