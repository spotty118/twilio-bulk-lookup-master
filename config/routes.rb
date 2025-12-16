require 'sidekiq/web'

Rails.application.routes.draw do
  # Devise authentication for admin users
  devise_for :admin_users, ActiveAdmin::Devise.config

  # Protect Sidekiq Web UI with admin authentication
  authenticate :admin_user do
    mount Sidekiq::Web => '/sidekiq'
  end

  # ActiveAdmin routes
  ActiveAdmin.routes(self)

  # Bulk lookup trigger
  get '/lookup', to: 'lookup#run'

  # Webhook endpoints
  namespace :webhooks do
    post 'twilio/sms_status', to: 'webhooks#twilio_sms_status'
    post 'twilio/voice_status', to: 'webhooks#twilio_voice_status'
    post 'twilio/trust_hub', to: 'webhooks#twilio_trust_hub'
    post 'generic', to: 'webhooks#generic'
  end

  # Health check endpoints (Kubernetes-compatible)
  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'health' => 'health#show', as: :health_check           # Liveness probe
  get 'health/ready' => 'health#ready', as: :health_ready    # Readiness probe
  get 'health/detailed' => 'health#detailed', as: :health_detailed
  get 'health/queue' => 'health#queue', as: :health_queue

  # PWA files
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  # Root route
  root to: redirect('/admin')
end
