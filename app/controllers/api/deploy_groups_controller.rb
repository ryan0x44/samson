# frozen_string_literal: true
class Api::DeployGroupsController < Api::BaseController
  skip_before_action :require_project, only: :index
  before_action :enabled?

  def index
    render json: paginate(DeployGroup.all)
  end

  def deploy_groups
    render json: paginate(stage.deploy_groups)
  end

  def update_deploy_groups
    if !production_change?
      stage.deploy_groups = deploy_groups_to_add
      stage.save!
      head :no_content
    else
      render json: {message: "Do not modify production via the API"}, status: 403
    end
  end

  protected

  def stage
    @project.stages.where(id: params[:id]).first!
  end

  def deploy_groups_to_add
    DeployGroup.where(id: params[:deploy_group_ids])
  end

  def production_change?
    stage && stage.production?
  end

  def enabled?
    return if DeployGroup.enabled?
    render json: {message: "DeployGroups are not enabled."}, status: :precondition_failed
    false
  end
end
