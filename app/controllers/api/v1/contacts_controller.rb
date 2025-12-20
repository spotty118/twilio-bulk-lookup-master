module Api
  module V1
    class ContactsController < BaseController
      def index
        contacts = Contact.order(created_at: :desc).page(params[:page]).per(25)

        render json: {
          contacts: contacts.map { |c| contact_json(c) },
          meta: {
            current_page: contacts.current_page,
            total_pages: contacts.total_pages,
            total_count: contacts.total_count
          }
        }
      end

      def show
        contact = Contact.find(params[:id])
        render json: { contact: contact_json(contact) }
      end

      def create
        contact = Contact.find_or_initialize_by(
          raw_phone_number: params[:phone_number]
        )

        # Reset failed contacts to a clean pending state
        saved = if contact.persisted? && contact.status == 'failed'
                  contact.reset_for_reprocessing!
                else
                  contact.status = 'pending' if contact.new_record?
                  contact.save
                end

        if saved
          # Trigger processing immediately
          if contact.status == 'pending'
            LookupRequestJob.perform_later(contact.id)
          end

          render json: { contact: contact_json(contact) }, status: :created
        else
          render json: { errors: contact.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def contact_json(contact)
        {
          id: contact.id,
          phone_number: contact.formatted_phone_number || contact.raw_phone_number,
          status: contact.status,
          carrier: contact.carrier_name,
          type: contact.line_type,
          country: contact.country_code,
          valid: contact.phone_valid,
          created_at: contact.created_at,
          updated_at: contact.updated_at
        }
      end
    end
  end
end
