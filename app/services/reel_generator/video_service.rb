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
    # # number_of_images_needed = (audio_length.to_f / min_image_length.to_f).ceil
    # seconds_to_fill = audio_length

    # # # do I have that number of images ?
    # images_total = images_urls.count
    # # max_images_shown = 
    # if images_total == 1
    #   # show same images
    # else
    #   # I need to know how to split the images_shown_length to fill the audio_length
      
    #   audio_length = 7


    #   # images_needed = 1
    #   # images_added = 0
    #   # images_counter = 0
    #   # while
    # end


    #####

    # images_load = {
    #   "image1": 3
    # }

    images_to_show = []
    min_image_length = 3 # seconds

    # first I need to know how many images are needed
    number_of_images_needed = audio_length / min_image_length
    if number_of_images_needed > images_urls.count
      images_urls << images_urls.last
    end
    images_urls[0...number_of_images_needed].each do |url|
      image_data = {}
      image_data[url] = min_image_length
      images_to_show << image_data
    end

    # if there are more seconds than image_length then calculate
    # the seconds reminder and add to last item

    extra_seconds = audio_length % min_image_length
    if extra_seconds > 0
      last_item = images_to_show.last
      last_item_key = last_item.keys.first
      last_item[last_item_key] = last_item[last_item_key] + extra_seconds
    end
      
    # second I need to for how long those images are gonna be shown
      


    #####

    # image_duration = audio_length / images_urls.count

    File.open("#{scene_images_folder}/input.txt", "w") do |f|
      image_x_path = nil
      images_to_show.each_with_index do |image_data, i|
        image_data.each do |url, duration|
          image_name   = "image00#{ i + 1 }.jpg"
          image_x_path = scene_images_folder + "/" + image_name
          puts "@@@@@@ This is the duration #{duration}"
          puts "@@@@@@ This is the url #{url}"
          Down.download(url, destination: image_x_path)
  
          duration.times do |i|
            10.times do |j|
              f.write("file '#{image_x_path}' \n")
              f.write("duration 0.1 \n")
            end
          end
  
          f.write("file '#{image_x_path}' \n") 
        end
      end
    end




  #   File.open("#{scene_images_folder}/input.txt", "w") do |f|
  #   image_x_path = nil
  #   images_urls[0...1].each_with_index do |url, i|
  #     image_name   = "image00#{ i + 1 }.jpg"
  #     image_x_path = scene_images_folder + "/" + image_name

  #     Down.download(url, destination: image_x_path)

  #     audio_length.times do |i|
  #       10.times do |j|
  #         f.write("file '#{image_x_path}' \n")
  #         f.write("duration 0.1 \n")
  #       end
  #     end

  #     f.write("file '#{image_x_path}' \n") 
  #   end
  # end




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
      s = 0.0
      i = 0
      # we need to change this to acount for the words per minute 1.3 words
      wps = 1.1 #(total_words.to_f / audio_length.to_f).ceil
      scene_text.split(" ").each_slice(3) do |sentence|
        f.write("#{i + 1} \n")

        f.write("00:00:#{s.to_s.gsub(".",",")}0 --> 00:00:#{(s + wps).round(1).to_s.gsub(".", ",")}0  \n")
        f.write(sentence.join(" ") + " \n")
        f.write("\n")
        s = (s + wps).round(1)
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




