class RubricsController < ApplicationController
  include Rails.application.routes.url_helpers

  before_action :require_levelbuilder_mode_or_test_env, except: [:submit_evaluations, :get_ai_evaluations, :get_teacher_evaluations, :ai_evaluation_status_for_user, :run_ai_evaluations_for_user]
  load_resource only: [:get_teacher_evaluations, :ai_evaluation_status_for_user, :run_ai_evaluations_for_user]
  load_and_authorize_resource except: [:submit_evaluations, :get_ai_evaluations, :get_teacher_evaluations, :ai_evaluation_status_for_user, :run_ai_evaluations_for_user]

  # GET /rubrics/:rubric_id/edit
  def edit
    @rubric = Rubric.find_by(id: params[:id])
    @lesson = @rubric.lesson
  end

  # GET /rubrics/new?lessonId=<lessonId>
  def new
    @lesson = Lesson.find_by(id: params[:lessonId])
    @rubric = Rubric.new
  end

  # POST /rubrics
  def create
    @rubric = Rubric.new(rubric_params)
    @lesson = @rubric.lesson
    if @rubric.save
      @rubric.lesson.script.write_script_json
      render json: {redirectUrl: edit_rubric_path(@rubric.id), rubricId: @rubric.id}
    else
      render :new
    end
  end

  # TODO(KT) [AITT-163]: add notice that rubric was successfully updated
  # PATCH /rubrics/:rubric_id
  def update
    @rubric = Rubric.find(params[:id])
    @lesson = @rubric.lesson
    if @rubric.update(rubric_params)
      @rubric.lesson.script.write_script_json
      render json: @rubric.summarize_for_rubric_edit
    else
      render action: 'edit'
    end
  end

  # POST /rubrics/:id/submit_evaluations
  def submit_evaluations
    return head :forbidden unless current_user&.teacher?
    permitted_params = params.permit(:id, :student_id)
    rubric = Rubric.find(permitted_params[:id])
    learning_goal_ids = LearningGoal.where(rubric_id: permitted_params[:id]).pluck(:id)
    evaluations = LearningGoalTeacherEvaluation.where(user_id: permitted_params[:student_id], learning_goal_id: learning_goal_ids, teacher_id: current_user.id)

    # Get project_id and source_version for learning goal evaluations
    user_storage_id = storage_id_for_user_id(permitted_params[:student_id])
    script_level = rubric.lesson.script_levels.find {|sl| sl.levels.include?(rubric.level)}
    channel_token = ChannelToken.find_channel_token(
      script_level.level,
      user_storage_id,
      script_level.script_id
    )
    project_id = nil
    version_id = nil
    if channel_token
      _owner_id, project_id = storage_decrypt_channel_id(channel_token.channel)
      source_data = SourceBucket.new.get(channel_token.channel, "main.json")
      if source_data[:status] == 'FOUND'
        version_id = source_data[:version_id]
      end
    end

    submitted_at = Time.now
    if evaluations.update_all(submitted_at: submitted_at, project_id: project_id, project_version: version_id)
      render json: {submittedAt: submitted_at}
    else
      return head :bad_request
    end
  end

  # GET /rubrics/:id/get_ai_evaluations
  def get_ai_evaluations
    return head :forbidden unless current_user&.teacher?

    permitted_params = params.transform_keys(&:underscore).permit(:id, :student_id)
    student = User.find(permitted_params[:student_id])
    return head :not_found unless student
    return head :forbidden unless can?(:manage, student)

    # Get the latest rubric evaluation
    rubric_ai_evaluation = RubricAiEvaluation.where(
      rubric_id: permitted_params[:id],
      user_id: student.id
    ).order(updated_at: :desc).first

    # Get the most recent learning goals based on the most recent graded rubric
    learning_goal_ai_evaluations = rubric_ai_evaluation&.learning_goal_ai_evaluations || []

    render json: learning_goal_ai_evaluations.map(&:summarize_for_instructor)
  end

  def get_teacher_evaluations
    return head :bad_request unless current_user

    learning_goal_ids = @rubric.learning_goals.pluck(:id)
    teacher_evaluations =
      LearningGoalTeacherEvaluation.where(user_id: current_user.id, learning_goal_id: learning_goal_ids).where.not(submitted_at: nil).
        group_by(&:learning_goal_id).
        map {|_, eval_list| eval_list.max_by(&:submitted_at)}
    render json: teacher_evaluations.map(&:summarize_for_participant)
  end

  def run_ai_evaluations_for_user
    user_id = params.transform_keys(&:underscore).require(:user_id)
    @user = User.find_by(id: user_id)
    return head :forbidden unless @user&.student_of?(current_user)

    # Find the rubric (must have something to evaluate)
    return head :bad_request unless @rubric

    script_level = @rubric.lesson.script_levels.find {|sl| sl.levels.include?(@rubric.level)}

    is_ai_experiment_enabled = current_user && Experiment.enabled?(user: current_user, script: script_level.script, experiment_name: 'ai-rubrics')
    return head :forbidden unless is_ai_experiment_enabled

    is_level_ai_enabled = EvaluateRubricJob.ai_enabled?(script_level)
    return head :bad_request unless is_level_ai_enabled

    attempted = attempted_at
    return render status: :bad_request, json: {error: 'Not attempted'} unless attempted
    evaluated = ai_evaluated_at
    return render status: :bad_request, json: {error: 'Already evaluated'} if evaluated && attempted < evaluated

    EvaluateRubricJob.perform_later(
      user_id: @user.id,
      requester_id: current_user.id,
      script_level_id: script_level.id,
    )
    return head :ok
  end

  def ai_evaluation_status_for_user
    user_id = params.transform_keys(&:underscore).require(:user_id)
    @user = User.find_by(id: user_id)
    return head :forbidden unless @user&.student_of?(current_user)

    script_level = @rubric.lesson.script_levels.find {|sl| sl.levels.include?(@rubric.level)}

    is_ai_experiment_enabled = current_user && Experiment.enabled?(user: current_user, script: script_level&.script, experiment_name: 'ai-rubrics')
    return head :forbidden unless is_ai_experiment_enabled

    is_level_ai_enabled = EvaluateRubricJob.ai_enabled?(script_level)
    return head :bad_request unless is_level_ai_enabled

    rubric_ai_evaluation = RubricAiEvaluation.where(
      rubric_id: @rubric.id,
      user_id: user_id
    ).order(updated_at: :desc).first

    status = nil
    if rubric_ai_evaluation&.status
      status = rubric_ai_evaluation.status
    end

    attempted = attempted_at
    evaluated = ai_evaluated_at
    render json: {
      status: status,
      attempted: !!attempted,
      lastAttemptEvaluated: !!attempted && !!evaluated && evaluated >= attempted,
      csrfToken: form_authenticity_token
    }
  end

  private

  def rubric_params
    params.transform_keys(&:underscore).permit(
      :level_id,
      :lesson_id,
      learning_goals_attributes: [
        :id,
        :learning_goal,
        :ai_enabled,
        :tips,
        :position,
        :_destroy,
        {
          learning_goal_evidence_levels_attributes: [
            :id,
            :learning_goal_id,
            :understanding,
            :teacher_description,
            :ai_prompt
          ]
        }
      ],
    )
  end

  def attempted_at
    script = @rubric.lesson.script
    level = @rubric.level
    user_level = UserLevel.find_by(user: @user, level: level, script: script)
    user_level&.updated_at
  end

  def ai_evaluated_at
    RubricAiEvaluation.
      where(rubric_id: @rubric.id, user_id: @user.id, status: SharedConstants::RUBRIC_AI_EVALUATION_STATUS[:SUCCESS]).
      order(updated_at: :desc).
      first&.
      created_at
  end
end
