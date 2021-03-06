# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe GroupScope do
  let(:deploy_group) { deploy_groups(:pod100) }
  let(:environment) { deploy_group.environment }
  let(:project) { projects(:test) }
  let(:deploy_group_scope_type_and_id) { "DeployGroup-#{deploy_group.id}" }
  let(:environment_variable) { EnvironmentVariable.new(name: "NAME", parent: project) } # TODO: don't use a plugin model

  describe "#scope_type_and_id=" do
    it "splits type and id" do
      environment_variable.scope_type_and_id = deploy_group_scope_type_and_id
      environment_variable.scope.must_equal deploy_group
      assert_valid environment_variable
    end

    it "is invalid with wrong type" do
      environment_variable.scope_type_and_id = "Stage-#{project.id}"
      refute_valid environment_variable
    end
  end

  describe "#scope_type_and_id" do
    it "builds from scope" do
      environment_variable.scope = deploy_group
      environment_variable.scope_type_and_id.must_equal deploy_group_scope_type_and_id
    end

    it "builds from nil so it is matched in rendered selects" do
      environment_variable.scope_type_and_id.must_be_nil
    end
  end

  describe "#priority" do
    it "fails on bad references" do
      e = assert_raises RuntimeError do
        EnvironmentVariable.new(scope_type: 'Foo', scope_id: 123).send(:priority)
      end
      e.message.must_equal "Unsupported scope Foo"
    end

    it "is higher with project" do
      EnvironmentVariable.new(parent_type: 'Project').send(:priority).must_equal [0, 2]
    end

    it "is lower without project" do
      EnvironmentVariable.new.send(:priority).must_equal [1, 2]
    end

    it "is higher with deploy group" do
      EnvironmentVariable.new(scope_type: 'DeployGroup').send(:priority).must_equal [1, 0]
    end

    it "is lower with environment" do
      EnvironmentVariable.new(scope_type: 'Environment').send(:priority).must_equal [1, 1]
    end
  end

  describe ".matches_scope?" do
    it "fails on bad references" do
      e = assert_raises RuntimeError do
        EnvironmentVariable.new(scope_type: 'Foo', scope_id: 123).send(:matches_scope?, deploy_groups(:pod1))
      end
      e.message.must_equal "Unsupported scope Foo"
    end

    it "does not match nothing" do
      refute EnvironmentVariable.new(scope_type: 'Foo', scope_id: 123).send(:matches_scope?, nil)
    end

    it "matches without scope" do
      assert EnvironmentVariable.new.send(:matches_scope?, deploy_group)
    end

    it "matches exact" do
      assert EnvironmentVariable.new(scope: deploy_group).send(:matches_scope?, deploy_group)
    end

    it "matches environment" do
      assert EnvironmentVariable.new(scope: deploy_group.environment).send(:matches_scope?, deploy_group)
    end

    it "does not matche other" do
      refute EnvironmentVariable.new(scope: deploy_groups(:pod1)).send(:matches_scope?, deploy_group)
    end
  end
end
