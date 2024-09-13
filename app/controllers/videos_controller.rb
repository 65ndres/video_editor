class VideosController < ApplicationController
  STORAGE_VOLUME_PATH = "/var/lib/output_media/"

  def generation_status
    required_params("gen_id")

    job = Job.find_by_gen_id(params["gen_id"])

    if job
      if job.status == 1
        render json: { "success": "true", "status": 204, "body": { "status": "Completed", "file_path": job.file_path  } }
      else
        render json: { "success": "true", "status": 204, "body": { "error": "Not ready yet" } }
      end
    else
      render json: { "success": "true", "status": 204, "body": { "error": "Record not found" } }
    end
  end


  private

  def required_params(*list)

    all_present = list.reduce(true) do |is_present, param|
      is_present && params[param].present?
    end

    if !all_present
      render json: { "success": "false", "status": 404, "body": { "error": "Missing params" } }
    end
  end

end
