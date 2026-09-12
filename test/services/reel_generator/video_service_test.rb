require "test_helper"
require "minitest/mock"

class ReelGenerator::VideoServiceTest < ActiveSupport::TestCase
  setup do
    @previous_output_media_path = ENV["OUTPUT_MEDIA_PATH"]
    @tmp = Dir.mktmpdir
    ENV["OUTPUT_MEDIA_PATH"] = @tmp
    ReelGenerator::VideoService.instance_variable_set(:@storage_volume_path, nil)
  end

  teardown do
    ENV["OUTPUT_MEDIA_PATH"] = @previous_output_media_path
    ReelGenerator::VideoService.instance_variable_set(:@storage_volume_path, nil)
    FileUtils.remove_entry(@tmp) if @tmp && File.directory?(@tmp)
  end

  test "persist_scene_media overwrites an existing video when given a new remote url" do
    dest = File.join(@tmp, "story-99", "scene-1690", "video", "output.mp4")
    FileUtils.mkdir_p(File.dirname(dest))
    File.binwrite(dest, "OLD_VIDEO")

    Down.stub(:download, ->(_url, destination:, **_) { File.binwrite(destination, "NEW_VIDEO") }) do
      result = ReelGenerator::VideoService.persist_scene_media(
        story_id: 99,
        scene_id: 1690,
        video_url: "https://cdn.example.com/new.mp4"
      )
      assert_equal File.expand_path(dest), result["video_path"]
    end

    assert_equal "NEW_VIDEO", File.binread(dest)
  end

  test "persist_scene_media keeps a local file when source is already on disk" do
    dest = File.join(@tmp, "story-99", "scene-1690", "video", "output.mp4")
    FileUtils.mkdir_p(File.dirname(dest))
    File.binwrite(dest, "LOCAL_VIDEO")

    downloaded = false
    Down.stub(:download, ->(*) { downloaded = true }) do
      result = ReelGenerator::VideoService.persist_scene_media(
        story_id: 99,
        scene_id: 1690,
        video_url: dest
      )
      assert_equal File.expand_path(dest), result["video_path"]
    end

    assert_not downloaded
    assert_equal "LOCAL_VIDEO", File.binread(dest)
  end
end
