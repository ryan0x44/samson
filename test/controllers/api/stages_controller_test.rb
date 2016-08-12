# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::StagesController do
  assert_route verb: "GET", path: "/api/projects/foo/stages",\
               to: "api/stages#index", params: { project_id: 'foo' }
  assert_route verb: "POST", path: "/api/stages/foo/clone",\
               to: "api/stages#clone", params: { stage_id: "foo" }
  assert_route verb: "GET", path: "/api/projects/foo/duplicable",\
               to: "api/stages#duplicable", params: { project_id: 'foo' }
  assert_route verb: "PUT", path: "/api/projects/foo/stages/1/duplicable",\
               to: "api/stages#put_duplicable", params: { project_id: 'foo', id: "1" }

  oauth_setup!
  let(:project) { projects(:test) }
  let(:stages) { project.stages }

  describe 'get #index' do
    before do
      get :index, project_id: project.id
    end

    subject { JSON.parse(response.body) }

    it 'succeeds' do
      assert_response :success
      response.content_type.must_equal 'application/json'
    end

    it 'contains a stage' do
      subject.size.must_equal 1
    end
  end

  describe 'post #clone' do
    describe '#stage_name' do
      before do
        @controller.stubs(:stage_to_clone).returns(stub(name: 'Foo'))
      end

      it 'returns copy of foo' do
        @controller.send(:stage_name).must_equal "Copy of Foo"
      end

      describe 'when the stage name is provided' do
        before do
          @controller.stubs(:params).returns(ActionController::Parameters.new(stage_name: "Foo"))
        end

        it 'uses the provided name' do
          @controller.send(:stage_name).must_equal "Foo"
        end
      end
    end

    it 'renders a cloned stage' do
      post :clone, stage_id: stages.first.id
      assert_response :created
    end

    describe 'when deploy group id\'s are included' do
      let(:dg) do
        dg = deploy_groups(:pod1)
        dg.save!
        dg
      end

      before do
        stage.deploy_groups_stages.delete_all
        post :clone, stage_id: stage.id, deploy_group_ids: [dg.id], stage_name: 'NewProduction'
      end

      let(:stage) { stages.first }
      subject do
        Stage.find_by_id JSON.parse(@response.body)['stage']['id']
      end

      it 'associates the newly cloned stage with the specified deploy groups' do
        subject.deploy_groups.size.must_equal 1, "More than one deploy group found for stage." \
          " #{stage.deploy_groups.to_a}"
        subject.deploy_groups.first.name.must_equal dg.name, "Wrong deploy group found " \
          "for stage: #{stage.deploy_groups.map(&:name)}"
      end
    end

    describe '#deploy_groups' do
      let(:dg) { deploy_groups(:pod1) }
      subject do
        @controller.stubs(:params).returns(ActionController::Parameters.new(deploy_group_ids: [dg.id]))
        @controller
      end

      it 'returns the deploy group matching the passed in ids' do
        subject.send(:deploy_groups).must_equal [dg]
      end
    end

    describe 'when the cloned stage is invalid' do
      before do
        post :clone, stage_id: stages.first.id, stage_name: stages.first.name
      end

      it 'does not clone' do
        assert_difference('Stage.count', 0) do
          post :clone, stage_id: stages.first.id, stage_name: stages.first.name
        end
      end

      it 'includes the errors' do
        post :clone, stage_id: stages.first.id, stage_name: stages.first.name
        response.body.must_include "already been taken"
      end
    end

    it 'creates a new stage' do
      assert_difference('Stage.count', 1) do
        post :clone, stage_id: stages.first.id
      end
    end
  end

  describe '#duplicable' do
    let(:project) { projects(:test) }
    let(:duplicable_stage) { project.stages.first }

    before do
      duplicable_stage.duplicable!
      get :duplicable, project_id: project.id
    end

    subject { JSON.parse(response.body) }

    it 'succeeds' do
      assert_response :success
    end

    it 'uses the StageSerializer' do
      assert_serializer "StageSerializer"
    end
  end

  describe '#put_duplicable' do
    let(:project) { projects(:test) }
    let(:duplicable_stage) { project.stages[0] }
    let(:non_duplicable_stage) { project.stages[1] }

    before do
      duplicable_stage.duplicable!
      put :put_duplicable, project_id: project.id, id: non_duplicable_stage.id
    end

    it 'responds with no_content' do
      assert_response :no_content
    end

    it 'updates the duplicable stage for that project' do
      non_duplicable_stage.reload.duplicable?.must_equal true
      duplicable_stage.reload.duplicable?.must_equal false
    end

    it 'has only one duplicable_stage' do
      project.stages.where(duplicable: true).count.must_equal 1
    end

    describe '#duplicable_stage' do
      it 'returns the stage for the id passed in' do
        @controller.send(:duplicable_stage).must_equal non_duplicable_stage
      end
    end
  end
end
