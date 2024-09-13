class ReelGenerator::VideosController < ApplicationController
  STORAGE_VOLUME_PATH = "/var/lib/output_media/"

  def generate_scene_video
    required_params("scene_id", "story_id", "images_urls")

    job = Job.new(params_sent: params, 
                  gen_id:      SecureRandom.uuid, 
                  action_name: "generate_scene_video",
                  class_name:  "ReelGenerator::VideoService")

    if job.save
      return render json: { "success": "OK", "status": 200, "body": { "gen_id": job.gen_id } }
    end

  end


  private

  def required_params(*list)

    all_present = list.reduce(true) do |is_present, param|
      is_present && params[param].present?
    end

    if !all_present
      return render json: { "success": "false", "status": 404, "body": { "error": "Missing params" } }
    end
  end

end
