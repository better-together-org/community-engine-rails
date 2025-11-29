# frozen_string_literal: true

module BetterTogether
  module Content
    # CRUD for content blocks independently of pages
    class BlocksController < ResourceController
      before_action :authenticate_user!
      before_action :disallow_robots
      before_action :set_block, only: %i[show edit update destroy]
      before_action only: %i[index], if: -> { Rails.env.development? } do
        # Make sure that all BLock subclasses are loaded in dev to generate new block buttons
        resource_class.load_all_subclasses
      end

      def index
        @blocks = policy_scope(resource_collection)
      end

      def create
        @block = resource_class.new(block_params.except(:media_signed_id))
        attach_signed_media(@block)
        authorize_resource

        if @block.save
          redirect_to content_block_path(@block),
                      notice: t('flash.generic.created', resource: t('resources.block'))
        else
          render :new
        end
      end

      def update
        @block.assign_attributes(block_params.except(:media_signed_id))
        attach_signed_media(@block)

        respond_to do |format|
          if @block.update(block_params)
            redirect_to content_block_path(@block),
                        notice: t('flash.generic.updated', resource: t('resources.block'))
          else
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(helpers.dom_id(@block, 'form'), partial: 'form',
                                                                                        locals: { block: @block })
            end
          end
        end
      end

      def new
        @block = resource_class.new(type: params[:block_type])

        respond_to(&:html)
      end

      def destroy
        @block.destroy unless @block.pages.any?

        redirect_to content_blocks_path, notice: t('flash.generic.destroyed', resource: t('resources.block'))
      end

      private

      def block_params
        params.require(:block).permit(
          :type, :media, :media_signed_id, :identifier,
          *resource_class.localized_block_attributes,
          *resource_class.storext_keys
        )
      end

      def set_block
        @block = set_resource_instance
      end

      def attach_signed_media(record)
        signed_id = params.dig(:block, :media_signed_id)
        record.media.attach(signed_id) if signed_id.present?
      end

      def resource_class
        BetterTogether::Content::Block
      end
    end
  end
end
