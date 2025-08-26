# frozen_string_literal: true

module BetterTogether
  class PersonBlocksController < ApplicationController # rubocop:todo Style/Documentation, Metrics/ClassLength
    before_action :authenticate_user!
    before_action :set_person_block, only: :destroy
    after_action :verify_authorized

    def index # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize PersonBlock

      # AC-2.11: I can search through my blocked users by name and slug
      @blocked_people = helpers.current_person.blocked_people
      if params[:search].present?
        # Search by translated name and slug using includes and references
        # Apply policy scope to ensure only authorized people are searchable
        search_term = params[:search].strip
        authorized_person_ids = policy_scope(BetterTogether::Person).pluck(:id)

        @blocked_people = @blocked_people.where(id: authorized_person_ids)
                                         .includes(:string_translations)
                                         .references(:string_translations)
                                         .where(string_translations: { key: %w[name slug] })
                                         .where('string_translations.value ILIKE ?', "%#{search_term}%")
                                         .distinct
      end

      # AC-2.12: I can see when I blocked each user (provide person_blocks for timestamp info)
      @person_blocks = helpers.current_person.person_blocks.includes(:blocked)
      if params[:search].present?
        # Filter person_blocks by matching blocked person names and slugs
        # Apply policy scope to ensure only authorized people are searchable
        search_term = params[:search].strip
        authorized_person_ids = policy_scope(BetterTogether::Person).pluck(:id)

        @person_blocks = @person_blocks.joins(:blocked)
                                       .where(better_together_people: { id: authorized_person_ids })
                                       .includes(blocked: :string_translations)
                                       .references(:string_translations)
                                       .where(string_translations: { key: %w[name slug] })
                                       .where('string_translations.value ILIKE ?', "%#{search_term}%")
                                       .distinct
      end

      # AC-2.15: I can see how many users I have blocked
      @blocked_count = @blocked_people.count
    end

    def new
      authorize PersonBlock
      @person_block = helpers.current_person.person_blocks.build
    end

    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # rubocop:todo Layout/IndentationWidth
        @person_block = helpers.current_person.person_blocks.new(person_block_params)
  # rubocop:enable Layout/IndentationWidth

  authorize @person_block # rubocop:todo Layout/IndentationConsistency

  respond_to do |format| # rubocop:todo Layout/IndentationConsistency
    if @person_block.save
      # AC-2.9: I receive confirmation when blocking/unblocking users
      flash[:notice] = t('better_together.person_blocks.notices.blocked')
      format.html { redirect_to person_blocks_path }
      format.turbo_stream do
        redirect_to person_blocks_path(locale: locale), status: :see_other
      end
    else
      flash[:alert] = @person_block.errors.full_messages.to_sentence
      format.html { redirect_to person_blocks_path }
      format.turbo_stream do
        render 'new', status: :unprocessable_entity
      end
    end
  end
    end

    def search
      authorize PersonBlock

      search_term = params[:q].to_s.strip
      blockable_people = find_blockable_people(search_term)
      people_data = format_people_for_select(blockable_people)

      render json: people_data
    end

    def destroy
      authorize @person_block
      @person_block.destroy

      respond_to do |format|
        # AC-2.9: I receive confirmation when blocking/unblocking users
        flash[:notice] = t('better_together.person_blocks.notices.unblocked')
        format.html { redirect_to person_blocks_path }
        format.turbo_stream do
          redirect_to person_blocks_path(locale: locale), status: :see_other
        end
      end
    end

    private

    def locale
      params[:locale] || I18n.default_locale
    end

    def set_person_block
      current_person = helpers.current_person
      return render_not_found unless current_person

      @person_block = current_person.person_blocks.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_not_found
    end

    def person_block_params
      params.require(:person_block).permit(:blocked_id)
    end

    def find_blockable_people(search_term)
      current_person = helpers.current_person
      blockable_people = base_blockable_people_scope(current_person)

      return blockable_people unless search_term.present?

      filter_by_search_term(blockable_people, search_term)
    end

    def base_blockable_people_scope(current_person)
      policy_scope(BetterTogether::Person)
        .where.not(id: current_person.id) # Can't block yourself
        .where.not(id: current_person.blocked_people.select(:id)) # Already blocked
    end

    def filter_by_search_term(scope, search_term)
      search_pattern = "%#{search_term}%"
      scope.i18n.where(
        'mobility_string_translations.value ILIKE ?',
        search_pattern
      ).where(
        mobility_string_translations: { key: %w[name slug] }
      )
    end

    def format_people_for_select(people)
      people.limit(20).map do |person|
        {
          text: person.name, # This will be the display text
          value: person.id.to_s,
          data: {
            slug: person.slug
          }
        }
      end
    end
  end
end
