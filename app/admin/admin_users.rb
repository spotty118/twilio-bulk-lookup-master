ActiveAdmin.register AdminUser do
  menu priority: 4, label: "Admin Users"
  
  # ========================================
  # Index View
  # ========================================
  index do
    selectable_column
    id_column
    
    column :email do |user|
      div do
        strong user.email
        if user == current_admin_user
          status_tag "You", class: "pending", style: "margin-left: 8px;"
        end
      end
    end
    
    column "Sign In Count", :sign_in_count do |user|
      number_with_delimiter(user.sign_in_count)
    end
    
    column "Last Sign In" do |user|
      if user.current_sign_in_at
        div do
          div user.current_sign_in_at.strftime("%b %d, %Y %H:%M")
          div style: "color: #6c757d; font-size: 12px;" do
            "from #{user.current_sign_in_ip}"
          end
        end
      else
        span "Never", style: "color: #6c757d;"
      end
    end
    
    column "Status" do |user|
      if user.current_sign_in_at && user.current_sign_in_at > 30.days.ago
        status_tag "Active", class: "completed"
      elsif user.current_sign_in_at
        status_tag "Inactive", class: "warning"
      else
        status_tag "Never Logged In", class: "failed"
      end
    end
    
    column "Created" do |user|
      time_ago_in_words(user.created_at) + " ago"
    end
    
    actions
  end

  # ========================================
  # Filters
  # ========================================
  filter :email
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  # ========================================
  # Form (Edit/New)
  # ========================================
  form do |f|
    f.semantic_errors
    
    f.inputs "Admin Details" do
      f.input :email, 
              hint: "This will be used to log in to the admin panel",
              input_html: { autocomplete: "username" }
      
      if f.object.new_record?
        f.input :password,
                hint: "Minimum 8 characters recommended",
                input_html: { autocomplete: "new-password" }
        f.input :password_confirmation,
                label: "Confirm Password",
                input_html: { autocomplete: "new-password" }
      else
        f.input :password,
                hint: "Leave blank to keep current password. Minimum 8 characters if changing.",
                input_html: { autocomplete: "new-password" }
        f.input :password_confirmation,
                label: "Confirm Password",
                hint: "Required if changing password",
                input_html: { autocomplete: "new-password" }
      end
    end
    
    f.actions do
      f.action :submit, 
               label: f.object.new_record? ? "Create Admin User" : "Update Admin User",
               button_html: { class: "button primary" }
      f.action :cancel
    end
  end

  # ========================================
  # Show Page
  # ========================================
  show do
    attributes_table do
      row :id
      
      row :email do |user|
        div do
          strong user.email
          if user == current_admin_user
            status_tag "Current User", class: "pending", style: "margin-left: 8px;"
          end
        end
      end
      
      row "Account Status" do |user|
        if user.current_sign_in_at && user.current_sign_in_at > 30.days.ago
          status_tag "Active", class: "completed"
        elsif user.current_sign_in_at
          status_tag "Inactive (#{time_ago_in_words(user.current_sign_in_at)} ago)", class: "warning"
        else
          status_tag "Never Logged In", class: "failed"
        end
      end
      
      row :sign_in_count do |user|
        number_with_delimiter(user.sign_in_count)
      end
      
      row :current_sign_in_at do |user|
        user.current_sign_in_at&.strftime("%B %d, %Y at %H:%M") || "Never"
      end
      
      row :current_sign_in_ip
      
      row :last_sign_in_at do |user|
        user.last_sign_in_at&.strftime("%B %d, %Y at %H:%M") || "N/A"
      end
      
      row :last_sign_in_ip
      
      row :created_at do |user|
        div do
          div user.created_at.strftime("%B %d, %Y at %H:%M")
          div style: "color: #6c757d; font-size: 12px;" do
            "(#{time_ago_in_words(user.created_at)} ago)"
          end
        end
      end
      
      row :updated_at do |user|
        div do
          div user.updated_at.strftime("%B %d, %Y at %H:%M")
          div style: "color: #6c757d; font-size: 12px;" do
            "(#{time_ago_in_words(user.updated_at)} ago)"
          end
        end
      end
    end
    
    panel "Security Information" do
      div style: "background: #f8f9fa; padding: 15px; border-radius: 8px;" do
        h4 "Password Security", style: "margin-top: 0;"
        
        ul do
          li "Passwords are encrypted using bcrypt"
          li "Password reset tokens expire after 6 hours"
          li "Multiple failed login attempts will lock the account temporarily"
        end
        
        if admin_user == current_admin_user
          div style: "margin-top: 15px; padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
            strong "⚠️ Notice: "
            span "You are viewing your own account. Be careful when making changes to avoid locking yourself out."
          end
        end
      end
    end
    
    active_admin_comments
  end
  
  # ========================================
  # Controller Customization
  # ========================================
  controller do
    def update
      # Allow password updates without current password in admin
      if params[:admin_user][:password].blank?
        params[:admin_user].delete(:password)
        params[:admin_user].delete(:password_confirmation)
      end
      
      super
    end
    
    def destroy
      # Prevent deleting yourself
      if resource == current_admin_user
        redirect_to admin_admin_users_path, alert: "You cannot delete your own account!"
        return
      end
      
      # Prevent deleting last admin
      if AdminUser.count <= 1
        redirect_to admin_admin_users_path, alert: "Cannot delete the last admin user!"
        return
      end
      
      super
    end
  end
  
  # ========================================
  # Permissions
  # ========================================
  permit_params :email, :password, :password_confirmation
end
