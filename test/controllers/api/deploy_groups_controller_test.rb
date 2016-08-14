# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::DeployGroupsController do
  assert_route verb: "GET", path: "/api/deploy_groups", to: "api/deploy_groups#index"
  assert_route verb: "GET", path: "/api/projects/1/stages/2/deploy_groups", \
               to: "api/deploy_groups#deploy_groups", params: {project_id: "1", id: "2"}
  assert_route verb: "PUT", path: "/api/projects/1/stages/2/deploy_groups", \
               to: "api/deploy_groups#update_deploy_groups", \
               params: {project_id: "1", id: "2"}

  oauth_setup!

  describe 'when deploy_groups is disabled' do
    before do
      DeployGroup.stubs(:enabled?).returns(false)
      get :index
    end

    it 'returns precondition_failed' do
      assert_response :precondition_failed
    end
  end

  describe 'when deploy_groups are enabled' do
    before do
      DeployGroup.stubs(:enabled?).returns(true)
    end

    describe '#index' do
      before do
        get :index
      end

      subject { JSON.parse(response.body) }

      it 'succeeds' do
        assert_response :success
      end

      it 'lists deploy_groups' do
        subject.keys.must_equal ['deploy_groups']
        subject['deploy_groups'].first.keys.sort.must_equal ["id", "kubernetes_cluster", "name"]
      end
    end

    describe '#deploy_groups' do
      before do
        get :deploy_groups, project_id: project.id, id: stage.id
      end

      let(:project) { projects(:test) }
      let(:stage) { project.stages.first }

      subject { JSON.parse(response.body) }

      it 'lists the associated deploy_groups for a project/stage' do
        subject.keys.must_equal ['deploy_groups']
        subject['deploy_groups'].first.keys.sort.must_equal ["id", "kubernetes_cluster", "name"]
      end

      it 'lists the correct deploy groups' do
        subject['deploy_groups'].map { |dg| dg['id'] }.must_equal stage.deploy_groups.map(&:id)
      end
    end

    describe 'put #deploy_groups' do
      let(:project) { projects(:test) }
      let(:stage) { project.stages.first }
      let(:dg) { deploy_groups(:pod100) }
      let(:dg_ids) { [dg.id] }

      describe 'non-production stages' do
        before do
          @controller.stubs(:production_change?).returns(false)
          stage.deploy_groups.delete_all
          stage.deploy_groups.map(&:id).wont_include(dg.id)
          put :update_deploy_groups, project_id: project.id, id: stage.id, \
                                     deploy_group_ids: dg_ids
        end

        it 'returns no_content' do
          assert_response :no_content
        end

        it 'sets the new deploy_group' do
          stage.reload.deploy_groups.map(&:id).must_include(dg.id)
        end

        describe 'multiple deploy_groups' do
          let(:dg1) { deploy_groups(:pod1) }
          let(:dg2) { deploy_groups(:pod2) }
          let(:dg_ids) { [dg1.id, dg2.id] }

          before do
            stage.deploy_groups_stages.delete_all
            stage.reload.deploy_groups.count.must_equal 0
            put :update_deploy_groups, project_id: project.id, id: stage.id, \
                                       deploy_group_ids: dg_ids
          end

          it 'adds all the deploy groups' do
            stage.reload.deploy_groups.count.must_equal 2
            stage.deploy_groups.map(&:id).must_equal dg_ids
          end
        end
      end

      describe 'production stage' do
        before do
          @controller.stubs(:production_change?).returns(true)
          put :update_deploy_groups, project_id: project.id, id: stage.id, \
                                     deploy_group_ids: dg_ids
        end

        subject { JSON.parse(response.body) }

        it 'returns forbidden' do
          assert_response :forbidden
        end

        it 'gives a message why the change failed' do
          subject['message'].must_equal 'Do not modify production via the API'
        end
      end

      describe '#production_change?' do
        subject do
          @controller.stubs(:stage).returns(dg.stages.first)
          @controller
        end

        describe 'for non-production stage' do
          let(:dg) { deploy_groups(:pod100) }

          it 'returns false' do
            subject.send(:production_change?).must_equal false
          end
        end

        describe 'production stage' do
          let(:dg) { deploy_groups(:pod1) }

          it 'returns true' do
            subject.send(:production_change?).must_equal true
          end
        end
      end
    end
  end
end
