# frozen_string_literal: true

module BetterTogether
  # Renders signed hidden challenge fields for CE's built-in bot defense.
  module BotDefenseHelper
    def bot_defense_fields(form_id)
      challenge = bot_defense_challenge(form_id)

      safe_join(
        [
          hidden_field_tag('bot_defense[token]', challenge.token),
          bot_defense_trap_markup(challenge)
        ]
      )
    end

    private

    def bot_defense_challenge(form_id)
      BetterTogether::BotDefense::Challenge.issue(form_id:, user_agent: request.user_agent)
    end

    def bot_defense_trap_markup(challenge)
      content_tag(
        :div,
        class: 'better-together-bot-defense-trap',
        style: 'position:absolute;left:-9999px;top:auto;width:1px;height:1px;overflow:hidden;',
        'aria-hidden': 'true'
      ) do
        safe_join([bot_defense_trap_label(challenge), bot_defense_trap_input(challenge)])
      end
    end

    def bot_defense_trap_label(challenge)
      label_tag(
        bot_defense_trap_input_id(challenge),
        t('better_together.bot_defense.trap_label', default: 'Leave this field blank')
      )
    end

    def bot_defense_trap_input(challenge)
      text_field_tag(
        "bot_defense[trap_values][#{challenge.trap_field}]",
        nil,
        id: bot_defense_trap_input_id(challenge),
        autocomplete: 'off',
        tabindex: -1
      )
    end

    def bot_defense_trap_input_id(challenge)
      "bot_defense_trap_#{challenge.trap_field}"
    end
  end
end
