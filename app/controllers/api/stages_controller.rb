# frozen_string_literal: true
class Api::StagesController < Api::BaseController
  skip_before_action :require_project, only: :clone

  def index
    render json: @project.stages
  end

  def clone
    new_stage = Stage.build_clone(stage_to_clone)
    new_stage.name = stage_name
    new_stage.deploy_groups = deploy_groups if deploy_groups.any?
    if new_stage.save
      render json: new_stage, status: 201
    else
      render json: new_stage.errors, status: 422
    end
  end

  def duplicable
    render json: duplicable_stage
  end

  def put_duplicable
    duplicable_stage.duplicable!
    head :no_content
  end

  private

  def stage_to_clone
    Stage.find_by_id(params.require(:stage_id))
  end

  def stage_name
    params.fetch(:stage_name, "Copy of #{stage_to_clone.name}")
  end

  def deploy_group_ids
    params.fetch(:deploy_group_ids, [])
  end

  def deploy_groups
    DeployGroup.where(id: deploy_group_ids)
  end

  def duplicable_stage
    @project.stages.where(id: params[:id]).first!
  end
end
