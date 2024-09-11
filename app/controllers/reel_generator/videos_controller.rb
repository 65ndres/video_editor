class ReelGenerator::VideosController < ApplicationController

  def generation_status
  end

  def generate_video # maybe this souldl be a model method
    puts "Here I made it tothe thing"
    # if params[:source] == "reel_generator"
    #   if params[:action] == "genrate_video_from_images"

    #   elsif params["action"] == "merge_audio_video"
    #   else
    #   end

    # end
  end

  def generate_video_from_images # is should be part of the service
    # check where it comes form to use proper service ?
    settings_file = file.txt
    response = `ffmpeg -f concat -i input.txt -vsync vfr -pix_fmt yuv420p output.mp4`
    
  end


    # 1. make sure needed_params are present
    # 2. Crate Job model and return gen id
    # 3. 
    # a story will be created if ther is not one, otherwise 
    # it will create a scene and return a gen id
    # Simple one model application

    # gen_id
    # action_name: "string"
    # file_path
    # params_sent

    # we will get the story and scene id

    # video_editor
      # |
      # |-----> story-1 (maybe a uuid for foler naem is better)
          # |
          # |
          # |----> scene-id
              #  |
              #  |
              #  |----> images
              #  |
              #  |----> scene_video
              #  |
              #  |----> merged_audio_video
                  #   -> audios
                  #   ->
                  # ->

    # Story
    #   # id
    #   # uuid
    # Scened
    #   # gen id
      # path to images
      # path to video


    #  create a story and return id the uuid?

  # end
end
