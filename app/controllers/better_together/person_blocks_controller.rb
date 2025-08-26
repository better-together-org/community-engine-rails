# frozen_string_literal: true

module BetterTogether
  class PersonBlocksController < ApplicationController # rubocop:todo Style/Documentation
    before_action :authenticate_user!
    before_action :set_person_block, only: :destroy
    after_action :verify_authorized

    def index # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize PersonBlock

      # AC-2.11: I can search through my blocked users by name
      @blocked_people = helpers.current_person.blocked_people
      if params[:search].present?
        # Search by translated name using includes and references
        # Apply policy scope to ensure only authorized people are searchable
        search_term = params[:search].strip
        authorized_person_ids = policy_scope(BetterTogether::Person).pluck(:id)

        @blocked_people = @blocked_people.where(id: authorized_person_ids)
                                         .includes(:string_translations)
                                         .references(:string_translations)
                                         .where(string_translations: { key: 'name' })
                                         .where('string_translations.value ILIKE ?', "%#{search_term}%")
                                         .distinct
      end

      # AC-2.12: I can see when I blocked each user (provide person_blocks for timestamp info)
      @person_blocks = helpers.current_person.person_blocks.includes(:blocked)
      if params[:search].present?
        # Filter person_blocks by matching blocked person names
        # Apply policy scope to ensure only authorized people are searchable
        search_term = params[:search].strip
        authorized_person_ids = policy_scope(BetterTogether::Person).pluck(:id)

        @person_blocks = @person_blocks.joins(:blocked)
                                       .where(better_together_people: { id: authorized_person_ids })
                                       .includes(blocked: :string_translations)
                                       .references(:string_translations)
                                       .where(string_translations: { key: 'name' })
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

  # AC-2.13: I can block a user by entering their username or email
  if params[:person_block][:blocked_identifier].present? # rubocop:todo Layout/IndentationConsistency
    target_person = BetterTogether::Person.find_by(identifier: params[:person_block][:blocked_identifier]) ||
                    # rubocop:todo Layout/LineLength
                    BetterTogether::Person.joins(:user).find_by(better_together_users: { email: params[:person_block][:blocked_identifier] })
    # rubocop:enable Layout/LineLength
    @person_block.blocked = target_person if target_person
  end

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
  end
end
