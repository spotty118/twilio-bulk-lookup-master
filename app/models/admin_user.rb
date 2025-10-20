class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :trackable, :validatable

  has_one :column_preference, class_name: 'AdminUserColumnPreference', dependent: :destroy

  # Returns column preferences for given resource
  def column_preferences_for(resource_name)
    AdminUserColumnPreference.for_user_and_resource(self, resource_name)
  end
end
