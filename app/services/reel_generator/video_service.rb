require "base64"
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

    unless fetch_media(audio_url, audio_x_path)
      Rails.logger.error("generate_scene_video audio download failed job=#{job.id} scene=#{scene_id} url=#{audio_url}")
      return
    end

    audio_length = probe_audio_length(audio_x_path)
    Rails.logger.info("generate_scene_video audio_length=#{audio_length} scene=#{scene_id}")

    images_urls = Array.wrap(images_urls).map(&:presence).compact
    if images_urls.blank?
      Rails.logger.error("generate_scene_video no images job=#{job.id} scene=#{scene_id}")
      return
    end

    images_to_show = still_durations_for_audio(images_urls, audio_length)

    input_txt  = File.expand_path("#{scene_images_folder}/input.txt")
    output_mp4 = File.expand_path("#{scene_video_folder}/#{video_name}")

    File.open(input_txt, "w") do |f|
      images_to_show.each_with_index do |image_data, i|
        image_data.each do |url, duration_tenths|
          image_name   = "image00#{ i + 1 }.jpg"
          image_x_path = File.expand_path("#{scene_images_folder}/#{image_name}")
          Rails.logger.info("generate_scene_video downloading image duration=#{duration_tenths / 10.0}s url=#{url}")
          Down.download(url, destination: image_x_path)

          duration_tenths.times do
            f.write("file '#{image_x_path}' \n")
            f.write("duration 0.1 \n")
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
    FileUtils.mkdir_p("#{scene_folder}/video")

    scene_video_path = "#{scene_folder}/video/output.mp4"
    audio_in = fetch_media(audio_url, audio_x_path)
    video_in = fetch_media(video_url, scene_video_path) || fetch_media(video_url, video_x_path)

    if audio_in.blank? || video_in.blank?
      Rails.logger.error(
        "merge_audio_video media missing job=#{job.id} scene=#{scene_id} " \
        "audio_url=#{audio_url} video_url=#{video_url} audio=#{audio_in} video=#{video_in}"
      )
      return
    end

    output_in = File.expand_path(output_mp4)

    # Absolute paths + no `cd`: after `cd` into merged folder, project-relative `-i` paths break.
    # Pad audio to the video length so concat does not start the next scene's
    # narration while this scene is still on screen.
    success = write_aligned_av(output_in, video_in, audio_path: audio_in)

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
    aligned_dir = File.join(story_video_folder, "aligned")
    FileUtils.rm_rf(aligned_dir)
    FileUtils.mkdir_p(aligned_dir)

    aligned_videos = []
    merged_videos.each_with_index do |merged_video_x_path, index|
      aligned_path = File.join(aligned_dir, format("%03d.mp4", index))
      unless write_aligned_av(aligned_path, merged_video_x_path)
        Rails.logger.error(
          "create_story_video align failed story=#{story_id} scene_video=#{merged_video_x_path}"
        )
        return
      end
      aligned_videos << aligned_path
    end

    File.open(input_file, "w") do |f|
      aligned_videos.each do |aligned_video_path|
        f.write("file '#{aligned_video_path}'\n")
      end
    end

    success = system(
      "ffmpeg", "-y",
      "-f", "concat", "-safe", "0",
      "-i", input_file,
      "-c", "copy",
      "-movflags", "+faststart",
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

  def self.persist_scene_media(story_id:, scene_id:, audio_url: nil, video_url: nil, audio_base64: nil)
    ensure_story_layout!(story_id)
    scene_folder = "#{story_folder_for(story_id)}/scene-#{scene_id}"
    audio_path   = "#{scene_folder}/audio/audio.mp3"
    video_path   = "#{scene_folder}/video/output.mp4"

    FileUtils.mkdir_p(File.dirname(audio_path))
    FileUtils.mkdir_p(File.dirname(video_path))

    saved_audio = write_audio_bytes(audio_path, audio_base64) ||
      (audio_url.present? ? fetch_media(audio_url, audio_path) : nil) ||
      (File.exist?(audio_path) ? File.expand_path(audio_path) : nil)
    saved_video = video_url.present? ? fetch_media(video_url, video_path) : (File.exist?(video_path) ? File.expand_path(video_path) : nil)

    { "audio_path" => saved_audio, "video_path" => saved_video }
  end

  def self.still_durations_for_audio(images_urls, audio_length)
    count = images_urls.length
    total_tenths = [audio_length, 1].max * 10
    base_tenths = total_tenths / count
    remainder = total_tenths % count

    images_urls.each_with_index.map do |url, index|
      tenths = base_tenths
      tenths += 1 if index < remainder
      tenths = 1 if tenths < 1
      { url => tenths }
    end
  end
  private_class_method :still_durations_for_audio

  def self.write_audio_bytes(audio_path, audio_base64)
    return if audio_base64.blank?

    File.binwrite(audio_path, Base64.decode64(audio_base64))
    File.expand_path(audio_path) if File.exist?(audio_path) && File.size(audio_path).positive?
  rescue ArgumentError => e
    Rails.logger.error("write_audio_bytes failed dest=#{audio_path} error=#{e.class}: #{e.message}")
    nil
  end
  private_class_method :write_audio_bytes

  def self.fetch_media(source, download_path)
    source = source.to_s
    dest = download_path.to_s
    remote = source.match?(/\Ahttps?:\/\//i)

    unless remote
      return File.expand_path(dest) if File.exist?(dest)
      return File.expand_path(source) if source.present? && File.exist?(source)
      return
    end

    # Always re-download remote URLs. Scene regeneration writes to the same
    # output.mp4 path, so keeping an existing dest would stitch the old clip.
    Down.download(
      source,
      destination: download_path,
      headers: { "User-Agent" => "video-editor" }
    )
    File.expand_path(download_path) if File.exist?(download_path)
  rescue Down::NotFound, Down::ClientError, Down::ServerError, Down::TimeoutError => e
    Rails.logger.error("fetch_media failed source=#{source} dest=#{download_path} error=#{e.class}: #{e.message}")
    nil
  end
  private_class_method :fetch_media

  def self.probe_audio_length(audio_path)
    length = probe_stream_duration(audio_path).ceil
    length.positive? ? length : 3
  end
  private_class_method :probe_audio_length

  # ffmpeg concat copies audio and video independently. If a clip's audio is
  # shorter than its video, the next clip's audio starts while the previous
  # picture is still showing. Pad audio with silence up to the video duration.
  def self.write_aligned_av(output_path, video_path, audio_path: nil)
    duration = probe_stream_duration(video_path, "v:0")
    return false unless duration.positive?

    duration_s = format("%.6f", duration)
    cmd = ["ffmpeg", "-y", "-i", video_path]
    cmd += ["-i", audio_path] if audio_path
    cmd += ["-c:v", "copy", "-c:a", "aac", "-ar", "44100", "-ac", "2"]
    cmd += ["-map", "0:v", "-map", "1:a"] if audio_path
    cmd += ["-af", "apad=whole_dur=#{duration_s}", "-t", duration_s, output_path]
    system(*cmd) && File.exist?(output_path)
  end
  private_class_method :write_aligned_av

  def self.probe_stream_duration(path, stream_spec = nil)
    cmd = ["ffprobe", "-v", "error"]
    cmd += ["-select_streams", stream_spec] if stream_spec
    cmd += ["-show_entries", stream_spec ? "stream=duration" : "format=duration", "-of", "csv=p=0", path]
    raw = IO.popen(cmd, err: File::NULL, &:read)
    duration = raw.to_f
    return duration if duration.positive?

    raw = IO.popen(
      ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
      err: File::NULL,
      &:read
    )
    raw.to_f
  end
  private_class_method :probe_stream_duration

end
