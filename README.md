# video_editor

Media for each story is stored under `story-{id}/` at the project root (override base path with `OUTPUT_MEDIA_PATH` for Docker).

## Folder layout

```
video_editor/
  story-{id}/
    scene-{scene_id}/
      audio/
      images/              # generate_scene_video pipeline only
      video/               # per-scene video from images
      merged_audio_video/  # Leonardo video + narration audio merged
        output.mp4
    video/                 # final stitched story video (sibling to scene folders)
      input.txt
      output.mp4
```

## Migrating from tmp/output_media

If stories were stored under `tmp/output_media/story-{id}/`, move them to the project root:

```bash
bundle exec rake 'output_media:migrate_story[35]'
# or migrate all at once:
bundle exec rake output_media:migrate_all
```
