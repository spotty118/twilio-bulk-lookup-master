module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_api_token!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def authenticate_api_token!
        authenticate_or_request_with_http_token do |token, _options|
          @current_user = AdminUser.find_by(api_token: token)
        end
      end

      attr_reader :current_user

      def not_found(error)
        render json: { error: 'Not Found', message: error.message }, status: :not_found
      end

      def unprocessable_entity(error)
        render json: { error: 'Unprocessable Entity', errors: error.record.errors.full_messages },
               status: :unprocessable_entity
      end

      def bad_request(error)
        render json: { error: 'Bad Request', message: error.message }, status: :bad_request
      end
    end
  end
end
