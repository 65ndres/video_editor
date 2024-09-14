Rails.application.routes.draw do

  get "up" => "rails/health#show", as: :rails_health_check
  get '/videos/generation_status/:gen_id', to:"videos#generation_status"

  namespace :reel_generator do
    post "/videos/generate_scene_video", to: "videos#generate_scene_video"
    post "/videos/merge_audio_video", to: "videos#merge_audio_video"
  end

end
