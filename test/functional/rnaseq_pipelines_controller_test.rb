require 'test_helper'

class RnaseqPipelinesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:rnaseq_pipelines)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create rnaseq_pipeline" do
    assert_difference('RnaseqPipeline.count') do
      post :create, :rnaseq_pipeline => { }
    end

    assert_redirected_to rnaseq_pipeline_path(assigns(:rnaseq_pipeline))
  end

  test "should show rnaseq_pipeline" do
    get :show, :id => rnaseq_pipelines(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => rnaseq_pipelines(:one).to_param
    assert_response :success
  end

  test "should update rnaseq_pipeline" do
    put :update, :id => rnaseq_pipelines(:one).to_param, :rnaseq_pipeline => { }
    assert_redirected_to rnaseq_pipeline_path(assigns(:rnaseq_pipeline))
  end

  test "should destroy rnaseq_pipeline" do
    assert_difference('RnaseqPipeline.count', -1) do
      delete :destroy, :id => rnaseq_pipelines(:one).to_param
    end

    assert_redirected_to rnaseq_pipelines_path
  end
end
