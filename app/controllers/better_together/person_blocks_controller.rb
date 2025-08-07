# frozen_string_literal: true

module BetterTogether
  class PersonBlocksController < ApplicationController # rubocop:todo Style/Documentation
    before_action :set_person_block, only: :destroy
    after_action :verify_authorized

    def index
      authorize PersonBlock
      @blocked_people = current_person.blocked_people
    end

    def create
      @person_block = current_person.person_blocks.new(person_block_params)
      authorize @person_block

      if @person_block.save
        redirect_to blocks_path, notice: 'Person was successfully blocked.'
      else
        redirect_to blocks_path, alert: @person_block.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @person_block
      @person_block.destroy
      redirect_to blocks_path, notice: 'Person was successfully unblocked.'
    end

    private

    def current_person
      current_user.person
    end

    def set_person_block
      @person_block = current_person.person_blocks.find(params[:id])
    end

    def person_block_params
      params.require(:person_block).permit(:blocked_id)
    end
  end
end
