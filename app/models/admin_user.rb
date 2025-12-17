class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable

  before_create :generate_api_token

  def generate_api_token
    self.api_token = SecureRandom.hex(24) while api_token.blank? || AdminUser.exists?(api_token: api_token)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email id updated_at sign_in_count last_sign_in_at current_sign_in_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
