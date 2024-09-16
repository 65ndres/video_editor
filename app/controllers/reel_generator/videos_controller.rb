class ReelGenerator::VideosController < ApplicationController

  def generate_scene_video
    required_params("scene_id", "story_id", "images_urls")

    job = Job.new(params_sent: params, 
                  gen_id:      SecureRandom.uuid, 
                  action_name: "generate_scene_video",
                  class_name:  "ReelGenerator::VideoService")

    if job.save
      render json: { "success": "OK", "status": 200, "body": { "gen_id": job.gen_id } }
    end
  end

  def merge_audio_video
    # required_params("video_path", "audio_url")


    job = Job.new(params_sent: params, 
                  gen_id:      SecureRandom.uuid, 
                  action_name: "merge_audio_video",
                  class_name:  "ReelGenerator::VideoService")


    puts "This is the job", params
    if job.save
      render json: { "success": "OK", "status": 200, "body": { "gen_id": job.gen_id } }
    end
  end

  private

  def required_params(*list)

    all_present = list.reduce(true) do |is_present, param|
      is_present && params[param].present?
    end

    if !all_present
      render json: { "success": "false", "status": 404, "body": { "error": "Missing parameters" } }
    end
  end

end
