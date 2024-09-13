class ReelGenerator::VideoService
  STORAGE_VOLUME_PATH = "/var/lib/output_media/"

  def self.generate_scene_video(job)

    params      = job.params_sent
    story_id    = params["story_id"]
    scene_id    = params["scene_id"]
    images_urls = params["images_urls"]
    video_name  = "output.mp4"

    story_folder        = "#{STORAGE_VOLUME_PATH}story-#{story_id}"
    scene_folder        = story_folder + "/scene-#{scene_id}"
    scene_images_folder = scene_folder + "/images"
    scene_video_folder  = scene_folder + "/video"  

    Dir.mkdir(story_folder)
    Dir.mkdir(scene_folder)
    Dir.mkdir(scene_images_folder)
    Dir.mkdir(scene_video_folder)

    File.open("#{scene_images_folder}/input.txt", "w") do |f|
      image_x_path = nil
      images_urls.each_with_index do |url, i|
        image_name   = "image00#{ i + 1 }.jpg"
        image_x_path = scene_images_folder + "/" + image_name

        Down.download(url, destination: image_x_path)
        f.write("file '#{image_x_path}' \n")
        f.write("duration 5 \n")
      end
      # this is a quirk with the library used to merge the images
      f.write("file '#{image_x_path}' \n") 
    end

    `cd #{scene_images_folder} && ffmpeg -f concat -safe 0 -i input.txt -vsync vfr -pix_fmt yuv420p #{video_name} && cp #{video_name} #{scene_video_folder}`

    job.update("status": 1, "file_path": scene_video_folder + '/' + video_name )
    # render json: { "success": "OK", "status": 200,"body": { "video_path": scene_video_folder } }
  end
end