# frozen_string_literal: true

module BetterTogether
  # Platform-scoped HTML CRUD for LLM-capable robots.
  class RobotsController < ApplicationController
    before_action :set_platform
    before_action :set_robot, only: %i[edit update destroy]
    after_action :verify_authorized

    def index
      authorize BetterTogether::Robot

      @robots = policy_scope(BetterTogether::Robot).merge(
        BetterTogether::Robot.available_for_platform(@platform)
      ).order(Arel.sql('CASE WHEN platform_id IS NULL THEN 1 ELSE 0 END'), :name)
      @translation_robot = BetterTogether::Robot.resolve(identifier: 'translation', platform: @platform)
      @translation_available = BetterTogether.translation_available?(platform: @platform)
      @openai_credentials_present = BetterTogether.openai_credentials_present?
    end

    def new
      @robot = @platform.robots.build(active: true, provider: BetterTogether::Robot::DEFAULT_PROVIDER)
      authorize @robot
      prepare_form_options
    end

    def create
      @robot = @platform.robots.build(robot_params)
      authorize @robot

      if @robot.save
        redirect_to platform_robots_path(@platform),
                    notice: t('better_together.robots.created'),
                    status: :see_other
      else
        prepare_form_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @robot
      prepare_form_options
    end

    def update
      authorize @robot

      if @robot.update(robot_params)
        redirect_to platform_robots_path(@platform),
                    notice: t('better_together.robots.updated'),
                    status: :see_other
      else
        prepare_form_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @robot
      @robot.destroy

      redirect_to platform_robots_path(@platform),
                  notice: t('better_together.robots.destroyed'),
                  status: :see_other
    end

    private

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_robot
      @robot = @platform.robots.find(params[:id])
    end

    def prepare_form_options
      @provider_options = (BetterTogether::Robot::PROVIDERS + [@robot.provider]).compact.uniq
      @robot_type_options = BetterTogether::Robot::ROBOT_TYPES
    end

    def robot_params # rubocop:disable Metrics/MethodLength
      raw_params = params.require(:robot).permit(
        :name,
        :identifier,
        :robot_type,
        :provider,
        :default_model,
        :default_embedding_model,
        :system_prompt,
        :active,
        settings: [:assume_model_exists]
      )

      existing_settings = @robot ? @robot.settings_hash.to_h : {}
      settings_params = raw_params.delete(:settings) || {}
      normalized_settings = existing_settings.merge(
        'assume_model_exists' => ActiveModel::Type::Boolean.new.cast(settings_params[:assume_model_exists])
      )

      raw_params.merge(settings: normalized_settings)
    end
  end
end
