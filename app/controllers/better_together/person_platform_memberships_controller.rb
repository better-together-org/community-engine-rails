# frozen_string_literal: true

module BetterTogether
  # Allows for CRUD operations for Person Platform Memberships
  class PersonPlatformMembershipsController < ApplicationController
    before_action :set_person_platform_membership, only: %i[show edit update destroy]

    # GET /person_platform_memberships
    def index
      @person_platform_memberships = PersonPlatformMembership.all
    end

    # GET /person_platform_memberships/1
    def show; end

    # GET /person_platform_memberships/new
    def new
      @person_platform_membership = PersonPlatformMembership.new
    end

    # GET /person_platform_memberships/1/edit
    def edit; end

    # POST /person_platform_memberships
    def create
      @person_platform_membership = PersonPlatformMembership.new(person_platform_membership_params)

      if @person_platform_membership.save
        redirect_to @person_platform_membership, only_path: true,
                                                 notice: 'Person platform membership was successfully created.'
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @person_platform_membership }
            )
          end
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /person_platform_memberships/1
    def update
      if @person_platform_membership.update(person_platform_membership_params)
        redirect_to @person_platform_membership, notice: 'Person platform membership was successfully updated.',
                                                 status: :see_other
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @person_platform_membership }
            )
          end
          format.html { render :edit, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /person_platform_memberships/1
    def destroy
      @person_platform_membership.destroy
      redirect_to person_platform_memberships_url, notice: 'Person platform membership was successfully destroyed.',
                                                   status: :see_other
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_person_platform_membership
      @person_platform_membership = PersonPlatformMembership.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def person_platform_membership_params
      params.fetch(:person_platform_membership, {})
    end
  end
end
