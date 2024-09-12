class ReelGenerator::VideosController < ApplicationController
  STORAGE_VOLUME_PATH = "/var/lib/output_videos/"

  
  
  def generation_status
  end

  def generate_video_from_images # maybe this souldl be a model method
        # settings_file = file.txt
    # response = `ffmpeg -f concat -i input.txt -vsync vfr -pix_fmt yuv420p output.mp4`

  end

  ########################### Custom method s from here 
  # private
  
  # def create_folder_structure
  #   scene_id     = params[:scene_id]
  #   story_id     = params[:story_id]
  #   story_folder = "#{STORAGE_VOLUME_PATH}story-#{story_id}"
  #   Dir.mkdir(story_folder)
  #   Dir.mkdir(story_folder + '/video')
  #   Dir.mkdir(story_folder + '/scene/video')
  #   Dir.mkdir(story_folder + '/scene/images')
  #   Dir.mkdir(story_folder + '/scene/audio')
  #   Dir.mkdir(story_folder + '/scene/merged_audio_video')
  # end



  def generate_scene_video

    scene_id     = params["scene_id"]
    story_id     = params["story_id"]
    image_urls   = params["images_urls"]

    # return render json: { "success": "false", "code" }

    story_folder        = "#{STORAGE_VOLUME_PATH}story-#{story_id}"
    scene_images_folder = story_folder + "/scene/images"
    scene_video_folder  = story_folder + "/scene/video"

    Dir.mkdir(story_folder)
    Dir.mkdir(story_folder + "/scene")
    Dir.mkdir(scene_images_folder)
    Dir.mkdir(scene_video_folder)
    # put guard to make sure the correct params are here

    # images_path = "#{STORAGE_VOLUME_PATH}story-#{story_id}/scene/images/"

    File.open("#{scene_images_folder}/input.txt", "w") do |f|
      image_x_path = nil
      image_urls.each_with_index do |url, i|
        image_name   = "image00#{ i + 1 }.jpg"
        image_x_path = scene_images_folder + "/" + image_name

        Down.download(url, destination: image_x_path)
        f.write("file '#{image_x_path}' \n")
        f.write("duration 5 \n")
      end
      # this is a quirk with the library used to merge the images
      f.write("file '#{image_x_path}' \n") 
    end

    
    # settings_file = file.txt
    response = `cd #{scene_images_folder} && ffmpeg -f concat -safe 0 -i input.txt -vsync vfr -pix_fmt yuv420p output.mp4 && cp output.mp4 #{scene_video_folder}`
    # puts "REEEEEEesponse  #{response}"
    
    render json: { "success": "OK", "status": 200,"body": { "video_path": scene_video_folder } }
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
