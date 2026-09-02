require "fileutils"

class ReelGenerator::VideoService
  # Local default: project root (story-{id}/...). Override with OUTPUT_MEDIA_PATH (e.g. Docker: /var/lib/output_media/).
  def self.storage_volume_path
    @storage_volume_path ||= begin
      base = ENV["OUTPUT_MEDIA_PATH"].presence || Rails.root.to_s
      base.end_with?("/") ? base : "#{base}/"
    end
  end

  def self.story_folder_for(story_id)
    "#{storage_volume_path}story-#{story_id}"
  end

  def self.story_video_folder_for(story_id)
    "#{story_folder_for(story_id)}/video"
  end

  def self.ensure_story_layout!(story_id)
    FileUtils.mkdir_p(story_folder_for(story_id))
    FileUtils.mkdir_p(story_video_folder_for(story_id))
  end

  def self.generate_scene_video(job)

    params      = job.params_sent
    story_id    = params["story_id"]
    scene_id    = params["scene_id"]
    audio_url   = params["audio_url"]
    images_urls = params["images_urls"]
    video_name  = "output.mp4"

    ensure_story_layout!(story_id)
    story_folder        = story_folder_for(story_id)
    scene_folder        = "#{story_folder}/scene-#{scene_id}"
    audio_folder        = "#{scene_folder}/audio"
    audio_x_path        = "#{audio_folder}/audio.mp3"
    scene_images_folder = "#{scene_folder}/images"
    scene_video_folder  = "#{scene_folder}/video"
    merged_audio_video_folder = "#{scene_folder}/merged_audio_video"

    FileUtils.mkdir_p(scene_folder)
    FileUtils.mkdir_p(scene_images_folder)
    FileUtils.mkdir_p(scene_video_folder)
    FileUtils.mkdir_p(audio_folder)
    FileUtils.mkdir_p(merged_audio_video_folder)

    Down.download(audio_url, destination: audio_x_path)

    audio_length = probe_audio_length(audio_x_path)
    Rails.logger.info("generate_scene_video audio_length=#{audio_length} scene=#{scene_id}")

    images_urls = Array.wrap(images_urls).map(&:presence).compact
    if images_urls.blank?
      Rails.logger.error("generate_scene_video no images job=#{job.id} scene=#{scene_id}")
      return
    end

    images_to_show = []
    min_image_length = 3 # seconds

    number_of_images_needed = [1, audio_length / min_image_length].max
    images_urls << images_urls.last while images_urls.length < number_of_images_needed
    images_urls[0...number_of_images_needed].each do |url|
      image_data = {}
      image_data[url] = min_image_length
      images_to_show << image_data
    end

    extra_seconds = audio_length % min_image_length
    if extra_seconds > 0 && images_to_show.last.present?
      last_item = images_to_show.last
      last_item_key = last_item.keys.first
      last_item[last_item_key] = last_item[last_item_key] + extra_seconds
    end

    input_txt  = File.expand_path("#{scene_images_folder}/input.txt")
    output_mp4 = File.expand_path("#{scene_video_folder}/#{video_name}")

    File.open(input_txt, "w") do |f|
      images_to_show.each_with_index do |image_data, i|
        image_data.each do |url, duration|
          image_name   = "image00#{ i + 1 }.jpg"
          image_x_path = File.expand_path("#{scene_images_folder}/#{image_name}")
          Rails.logger.info("generate_scene_video downloading image duration=#{duration} url=#{url}")
          Down.download(url, destination: image_x_path)

          duration.times do
            10.times do
              f.write("file '#{image_x_path}' \n")
              f.write("duration 0.1 \n")
            end
          end

          f.write("file '#{image_x_path}' \n")
        end
      end
    end

    concat_ok = system(
      "ffmpeg", "-y",
      "-f", "concat", "-safe", "0",
      "-i", input_txt,
      "-fps_mode", "vfr",
      "-pix_fmt", "yuv420p",
      output_mp4
    )

    unless concat_ok && File.exist?(output_mp4)
      Rails.logger.error("generate_scene_video concat failed job=#{job.id} scene=#{scene_id}")
      return
    end

    job.update("status": 1, "file_path": output_mp4)
  end


  def self.merge_audio_video(job)
    params       = job.params_sent
    story_id     = params["story_id"]
    audio_url    = params["audio_url"]
    scene_id     = params["scene_id"]
    video_url    = params["video_url"]
    audio_name   = "audio.mp3"

    story_folder              = story_folder_for(story_id)
    ensure_story_layout!(story_id)
    scene_folder              = "#{story_folder}/scene-#{scene_id}"
    audio_folder              = "#{scene_folder}/audio"
    merged_audio_video_folder = "#{scene_folder}/merged_audio_video"
    source_video_name         = "source_video.mp4"
    video_x_path              = "#{merged_audio_video_folder}/#{source_video_name}"
    audio_x_path              = "#{audio_folder}/#{audio_name}"
    output_mp4                = "#{merged_audio_video_folder}/output.mp4"

    FileUtils.mkdir_p(audio_folder)
    FileUtils.mkdir_p(merged_audio_video_folder)

    # binding.irb
    Down.download(audio_url, destination: audio_x_path)
    # Down.download(video_url, destination: video_x_path)

    video_in  = video_url
    puts "MIAAAA was here"
    audio_in  = File.expand_path(audio_x_path)
    output_in = File.expand_path(output_mp4)

    # Absolute paths + no `cd`: after `cd` into merged folder, project-relative `-i` paths break.
    success = system(
      "ffmpeg", "-y",
      "-i", video_in,
      "-i", audio_in,
      "-c:v", "copy",
      "-map", "0:v", "-map", "1:a",
      output_in
    )

    unless success && File.exist?(output_in)
      Rails.logger.error("merge_audio_video ffmpeg failed job=#{job.id} scene=#{scene_id}")
      return
    end

    job.update("status": 1, "file_path": output_mp4 )
  end


  def self.create_story_video(job)
    params             = job.params_sent
    story_id           = params["story_id"]
    story_folder       = story_folder_for(story_id)
    story_video_folder = story_video_folder_for(story_id)

    unless File.directory?(story_folder)
      Rails.logger.error("create_story_video missing story folder story=#{story_id} path=#{story_folder}")
      return
    end

    story_scenes_folders = Dir.children(story_folder).grep(/\Ascene-\d+\z/).sort

    merged_videos = story_scenes_folders.filter_map do |scene_folder|
      path = File.join(story_folder, scene_folder, "merged_audio_video", "output.mp4")
      path if File.exist?(path)
    end

    if merged_videos.empty?
      Rails.logger.error("create_story_video no merged scene videos story=#{story_id} path=#{story_folder}")
      return
    end

    ensure_story_layout!(story_id)
    input_file = File.join(story_video_folder, "input.txt")
    output_mp4 = File.join(story_video_folder, "output.mp4")

    File.open(input_file, "w") do |f|
      merged_videos.each do |merged_video_x_path|
        f.write("file '#{merged_video_x_path}' \n")
      end
    end

    success = system(
      "ffmpeg", "-y",
      "-f", "concat", "-safe", "0",
      "-i", input_file,
      "-vsync", "vfr", "-pix_fmt", "yuv420p",
      "-c", "copy",
      output_mp4
    )

    unless success && File.exist?(output_mp4)
      Rails.logger.error("create_story_video ffmpeg failed story=#{story_id}")
      return
    end

    job.update("status": 1, "file_path": output_mp4)
  end


  def self.folder_generator
  end

  def self.probe_audio_length(audio_path)
    raw = IO.popen(
      ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", audio_path],
      err: File::NULL,
      &:read
    )
    length = raw.to_f.ceil
    length.positive? ? length : 3
  end
  private_class_method :probe_audio_length

end
