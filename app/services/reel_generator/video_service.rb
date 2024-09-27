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

    image_duration = audio_length / images_urls.count

    puts "This are image_duration image_duration #{image_duration}"

    File.open("#{scene_images_folder}/input.txt", "w") do |f|
      image_x_path = nil
      images_urls.each_with_index do |url, i|
        image_name   = "image00#{ i + 1 }.jpg"
        image_x_path = scene_images_folder + "/" + image_name

        Down.download(url, destination: image_x_path)

        image_duration.times do |i|
          f.write("file '#{image_x_path}' \n")
          f.write("duration 1 \n")
        end
      end
      # this is a quirk with the library used to merge the images
      f.write("file '#{image_x_path}' \n") 
    end
    
    #create subtitles
    File.open("#{scene_video_folder}/subtitles.srt", "w") do |f|
    total_sentences    = scene_text.split(",").count
    sentence_step =  (audio_length.to_f / total_sentences.to_f).ceil
    s = 0
      scene_text.split(",").each_with_index do |sentence, index|
        f.write("#{index + 1} \n")
        f.write("00:00:#{s},000 --> 00:00:#{s + sentence_step},000 \n")
        f.write(sentence.strip + " \n")
        f.write("\n")
        s = s + sentence_step
      end

    end

    # # # create scene video from images
    `cd #{scene_images_folder} && ffmpeg -f concat -safe 0 -i input.txt -vsync vfr -pix_fmt yuv420p #{video_name} && cp #{video_name} #{scene_video_folder}`
    # # add subtitles
    `cd #{scene_video_folder} && ffmpeg -i #{video_name} -vf subtitles=subtitles.srt output_srt.mp4`


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
    # puts "I made it here tothe creat story !!!!!!!!"
    params               = job.params_sent
    story_id             = params["story_id"]
    story_folder         = "#{STORAGE_VOLUME_PATH}story-#{story_id}"

    puts "This is the Story folder #{story_id}"

    story_video_folder   = story_folder + "/" + "video"
    story_scenes_folders = Dir.new(story_folder).children.select { |folder| folder.include?('scene')}
    puts story_scenes_folders
  
    File.open("#{story_video_folder}/input.txt", "w") do |f|
    merged_video_x_path = nil
      story_scenes_folders.each do |scene_folder|
        puts "This is the escen #{scene_folder}"
        merged_video_x_path = story_folder + "/" + scene_folder + "/" + "merged_audio_video" + "/output.mp4"
        puts "Thisis the x path #{merged_video_x_path}"
        f.write("file '#{merged_video_x_path}' \n")
      end
      # f.write("file '#{merged_video_x_path}' \n")
    end

    `cd #{story_video_folder} && ffmpeg -f concat -safe 0 -i input.txt -vsync vfr -pix_fmt yuv420p -c copy output.mp4`

    job.update("status": 1, "file_path": story_video_folder + '/output.mp4' )
  end


  def self.folder_generator
  end

end




