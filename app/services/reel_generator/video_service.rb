class ReelGenerator::VideoService
  STORAGE_VOLUME_PATH      = "/var/lib/output_media/"

  def self.generate_scene_video(job)

    params      = job.params_sent
    story_id    = params["story_id"]
    scene_id    = params["scene_id"]
    audio_url   = params["audio_url"]
    images_urls = params["images_urls"]
    scene_text  = params["scene_text"]
    video_name  = "output.mp4"

    story_folder        = "#{STORAGE_VOLUME_PATH}story-#{story_id}"
    story_video_folder  = story_folder + "/video"
    scene_folder        = story_folder + "/scene-#{scene_id}"
    audio_folder        = scene_folder + "/audio"
    audio_x_path        = audio_folder + "/" + "audio.mp3"
    scene_images_folder = scene_folder + "/images"
    scene_video_folder  = scene_folder + "/video"
    merged_audio_video_folder = scene_folder + "/" + "merged_audio_video"


    Dir.mkdir(story_folder) if !File.exists?(story_folder)
    Dir.mkdir(scene_folder) if !File.exists?(scene_folder)
    Dir.mkdir(scene_images_folder) if !File.exists?(scene_images_folder)
    Dir.mkdir(scene_video_folder) if !File.exists?(scene_video_folder)
    Dir.mkdir(audio_folder) if !File.exists?(audio_folder)
    Dir.mkdir(merged_audio_video_folder) if !File.exists?(merged_audio_video_folder)
    Dir.mkdir(story_video_folder) if !File.exists?(story_video_folder)

    
    Down.download(audio_url, destination: audio_x_path)

    res = `cd #{scene_folder}/audio  && ffmpeg -i audio.mp3 2>&1 |grep -oP "[0-9]{2}:[0-9]{2}:[0-9]{2}"`
    audio_length = res.gsub("\n","").split(":")[-1].to_i

    puts "This is the audio length #{audio_length}"




    #####
    # min_image_length = 3 # seconds
    # number_of_images_needed = (audio_length.to_f / min_image_length.to_f).ceil

    # # do I have that number of images ?
    # images_total = images_urls.count
    # max_images_shown = 
    # if images_total == 1
    #   # show same images
    # elsif images_total == 5
    # end

    #####

    # image_duration = audio_length / images_urls.count

    File.open("#{scene_images_folder}/input.txt", "w") do |f|
      image_x_path = nil
      images_urls[0...1].each_with_index do |url, i|
        image_name   = "image00#{ i + 1 }.mp4"
        image_x_path = scene_images_folder + "/" + image_name

        Down.download(url, destination: image_x_path)
        # f.write("file '#{image_x_path}' \n")

        audio_length.times do |i|
          f.write("file '#{image_x_path}' \n")
          f.write("duration 1 \n")
        end

        f.write("file '#{image_x_path}' \n") 
      end
    end

    File.open("#{scene_video_folder}/subtitles.srt", "w") do |f|
      total_words  = scene_text.split(" ").count
      n = 1
      if total_words > 24
        n = 3
      elsif total_words > 11
        n = 2
      else
        n = 1
      end
      new_s = 0.0
      # We neeed tomake sure the images or video length is atleast the length of the voice (which is impossible with motion)
      # | This is the audio length 6
      # api-1    | HERE is the max number of images 1
      s = i = 0

      # READ!!! I tried showing 3 words per second but it all goes toshit 
      # get the length of the audio and based on the text length we can know how many wps ?
      wps = (total_words.to_f / audio_length.to_f).ceil
      scene_text.split(" ").each_slice(wps) do |sentence|
        f.write("#{i + 1} \n")

        f.write("00:00:#{s},000 --> 00:00:#{s + 1},000  \n")
        f.write(sentence.join(" ") + " \n")
        f.write("\n")
        s = s + 1
        i += 1
      end

    end

    # # # create scene video from images
    `cd #{scene_images_folder} && ffmpeg -f concat -safe 0 -i input.txt -vsync vfr -pix_fmt yuv420p pre_subtitles_output.mp4 && cp pre_subtitles_output.mp4 #{scene_video_folder}`
    # # add subtitles
    `cd #{scene_video_folder} && ffmpeg -i pre_subtitles_output.mp4 -vf subtitles=subtitles.srt:force_style='Alignment=10' #{video_name}`

    job.update("status": 1, "file_path": scene_video_folder + '/' + video_name )
  end


  def self.merge_audio_video(job)
    params       = job.params_sent
    story_id     = params["story_id"]
    scene_id     = params["scene_id"]
    video_x_path = params["video_path"]
    audio_name   = "audio.mp3"

    story_folder        = "#{STORAGE_VOLUME_PATH}story-#{story_id}"
    scene_folder        = story_folder + "/scene-#{scene_id}"
    audio_folder        = scene_folder + "/audio"
    audio_x_path        = audio_folder + "/" + audio_name
    merged_audio_video_folder = scene_folder + "/" + "merged_audio_video"

    `cd #{merged_audio_video_folder} && ffmpeg \
     -i #{video_x_path} -i #{audio_x_path} \
    -c:v copy \
    -map 0:v -map 1:a \
    -y output.mp4`

    job.update("status": 1, "file_path": merged_audio_video_folder + '/output.mp4' )
  end


  def self.create_story_video(job)
    params               = job.params_sent
    story_id             = params["story_id"]
    story_folder         = "#{STORAGE_VOLUME_PATH}story-#{story_id}"
    story_video_folder   = story_folder + "/" + "video"
    story_scenes_folders = Dir.new(story_folder).children.select { |folder| folder.include?('scene')}.sort!
  
    File.open("#{story_video_folder}/input.txt", "w") do |f|
    merged_video_x_path = nil
    # the folders must come sorted out
      story_scenes_folders.each do |scene_folder|
        merged_video_x_path = story_folder + "/" + scene_folder + "/" + "merged_audio_video" + "/output.mp4"
        f.write("file '#{merged_video_x_path}' \n")
      end
    end

    `cd #{story_video_folder} && ffmpeg -f concat -safe 0 -i input.txt -vsync vfr -pix_fmt yuv420p -c copy output.mp4`

    job.update("status": 1, "file_path": story_video_folder + '/output.mp4' )
  end


  def self.folder_generator
  end

end




