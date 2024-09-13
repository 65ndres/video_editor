class VideosController < ApplicationController
  STORAGE_VOLUME_PATH = "/var/lib/output_media/"

  def generation_status
    required_params("gen_id")
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
