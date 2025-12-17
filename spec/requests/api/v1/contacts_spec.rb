# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Contacts', type: :request do
  let(:admin_user) { create(:admin_user) }

  describe 'GET /api/v1/contacts' do
    context 'with valid authentication' do
      before do
        create_list(:contact, 3, :completed)
      end

      it 'returns paginated contacts' do
        get '/api/v1/contacts', headers: api_headers(admin_user)

        expect(response).to have_http_status(:ok)
        expect(json_response['contacts']).to be_an(Array)
        expect(json_response['contacts'].length).to eq(3)
        expect(json_response['meta']).to include(
          'current_page' => 1,
          'total_count' => 3
        )
      end

      it 'returns contacts in descending order by created_at' do
        get '/api/v1/contacts', headers: api_headers(admin_user)

        expect(response).to have_http_status(:ok)
        contacts = json_response['contacts']
        created_ats = contacts.map { |c| c['created_at'] }
        expect(created_ats).to eq(created_ats.sort.reverse)
      end
    end

    context 'without authentication' do
      it 'returns HTTP 401' do
        get '/api/v1/contacts', headers: unauthenticated_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns HTTP 401' do
        get '/api/v1/contacts', headers: invalid_token_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/contacts/:id' do
    context 'with valid authentication' do
      let(:contact) { create(:contact, :completed) }

      it 'returns the contact details' do
        get "/api/v1/contacts/#{contact.id}", headers: api_headers(admin_user)

        expect(response).to have_http_status(:ok)
        expect(json_response['contact']).to include(
          'id' => contact.id,
          'status' => 'completed'
        )
      end

      it 'returns 404 for non-existent contact' do
        get '/api/v1/contacts/999999', headers: api_headers(admin_user)

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Not Found')
      end
    end

    context 'without authentication' do
      let(:contact) { create(:contact) }

      it 'returns HTTP 401' do
        get "/api/v1/contacts/#{contact.id}", headers: unauthenticated_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/contacts' do
    context 'with valid authentication' do
      it 'creates a contact with valid phone number' do
        valid_phone = '+14155551234'

        expect {
          post '/api/v1/contacts',
               params: { phone_number: valid_phone }.to_json,
               headers: api_headers(admin_user)
        }.to change(Contact, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['contact']).to include(
          'phone_number' => valid_phone
        )
      end

      it 'enqueues LookupRequestJob for new contacts' do
        expect {
          post '/api/v1/contacts',
               params: { phone_number: '+14155558888' }.to_json,
               headers: api_headers(admin_user)
        }.to have_enqueued_job(LookupRequestJob)
      end

      it 'rejects invalid phone format' do
        invalid_phone = 'not-a-phone'

        post '/api/v1/contacts',
             params: { phone_number: invalid_phone }.to_json,
             headers: api_headers(admin_user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to be_present
      end

      it 'rejects empty phone number' do
        post '/api/v1/contacts',
             params: { phone_number: '' }.to_json,
             headers: api_headers(admin_user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without authentication' do
      it 'returns HTTP 401' do
        post '/api/v1/contacts',
             params: { phone_number: '+14155551234' }.to_json,
             headers: unauthenticated_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
