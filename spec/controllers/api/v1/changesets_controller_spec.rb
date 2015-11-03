describe Api::V1::ChangesetsController do
  before(:each) do
    allow(Figaro.env).to receive(:transitland_datastore_auth_token) { 'THISISANAPIKEY' }
    @request.env['HTTP_AUTHORIZATION'] = 'Token token=THISISANAPIKEY'
  end

  context 'GET index' do
    it 'returns all stops when no parameters provided' do
      create_list(:changeset, 2)
      get :index
      expect_json_types({ changesets: :array }) # TODO: remove root node?
      expect_json({ changesets: -> (changesets) {
        expect(changesets.length).to eq 2
      }})
    end
  end

  context 'GET show' do
    it 'returns a changeset when its ID is given' do
      create_list(:changeset, 2)
      get :show, id: Changeset.last.id
      expect_json({
        id: Changeset.last.id,
        applied: false,
        applied_at: nil
      })
    end

    it 'returns ChangePayloads in payload' do
      create_list(:changeset_with_payload, 2)
      changeset = Changeset.last
      get :show, id: changeset.id
      payloads = changeset.change_payloads.map {|x| x.payload_as_ruby_hash[:changes]}
      expect_json({
        id: changeset.id,
        payload: -> (payload) { payload[:changes].count == payloads.length},
        applied: false,
        applied_at: nil
      })
    end
  end

  context 'POST create' do
    it 'should be able to create a Changeset with an empty payload' do
      post :create, changeset: FactoryGirl.attributes_for(:changeset)
      expect(response.status).to eq 200
      expect(Changeset.count).to eq 1
      expect(ChangePayload.count).to eq 0
    end

    it 'should be able to create a Changeset with a valid payload' do
      post :create, changeset: FactoryGirl.attributes_for(:changeset_with_payload)
      expect(response.status).to eq 200
      expect(Changeset.count).to eq 1
      expect(ChangePayload.count).to eq 1
    end
    
    it 'should fail to create a Changeset with an invalid payload' do
      post :create, changeset: {
        changes: []
      }
      expect(response.status).to eq 400
      expect(Changeset.count).to eq 0
    end

    it 'should fail when API auth token is not provided' do
      @request.env['HTTP_AUTHORIZATION'] = nil
      post :create, changeset: {
        changes: []
      }
      expect(response.status).to eq 401
    end

    it 'should be able to instantly create and apply a Changeset with a valid payload' do
      attrs = FactoryGirl.attributes_for(:changeset_with_payload)
      attrs[:whenToApply] = 'instantlyIfClean'
      post :create, changeset: attrs
      expect(Changeset.count).to eq 1
      expect(Changeset.first.applied).to eq true
      expect(Stop.count).to eq 1
    end
  end

  context 'POST append' do
    it 'should be able to append a change payload to a Changeset' do
      changeset = create(:changeset)
      change = FactoryGirl.attributes_for(:change_payload)
      expect(Changeset.count).to eq 1
      expect(ChangePayload.count).to eq 0
      post :append, id: changeset.id, change: change
      expect(response.status).to eq 200
      expect(Changeset.count).to eq 1
      expect(ChangePayload.count).to eq 1    
    end
  end

  context 'POST update' do
    it "should be able to update a Changeset that hasn't yet been applied" do
      changeset = create(:changeset)
      post :update, id: changeset.id, changeset: {
        notes: 'this is the NEW note'
      }
      expect(changeset.reload.notes).to eq 'this is the NEW note'
    end

    it "shouldn't be able to append to an applied Changeset" do
      changeset = create(:changeset)
      changeset.update(applied: true)      
      change = FactoryGirl.attributes_for(:change_payload)
      post :append, id: changeset.id, change: change
      expect_json({ message: 'cannot update a Changeset that has already been applied' })
      expect(response.code).to eq '400'
    end
  end

  context 'POST check' do
    it 'should be able to identify a Changeset that will apply cleanly' do
      changeset = create(:changeset)
      post :check, id: changeset.id
      expect_json({ trialSucceeds: true })
      expect(changeset.applied).to eq false
    end

    it 'should be able to identify a Changeset that will NOT apply cleanly' do
      changeset = create(:changeset, payload: {
        changes: [
          action: 'destroy',
          stop: {
            onestopId: 's-5b2-Fake'
          }
        ]
      })
      post :check, id: changeset.id
      expect_json({ trialSucceeds: false })
      expect(changeset.applied).to eq false
    end
  end

  context 'POST apply' do
    it 'should be able to apply a clean Changeset' do
      changeset = create(:changeset, payload: {
        changes: [
          {
            action: 'createUpdate',
            stop: {
              onestopId: 's-9q8yt4b-1AvHoS',
              name: '1st Ave. & Holloway Street',
              operatorsServingStop: [
                {
                  operatorOnestopId: 'o-9q8y-SFMTA'
                }
              ]
            }
          }
        ]
      })
      expect(Stop.count).to eq 0
      post :apply, id: changeset
      expect(OnestopId.find!('s-9q8yt4b-1AvHoS').name).to eq '1st Ave. & Holloway Street'
      expect_json({ applied: true })
    end

    it "will fail gracefully when a Changeset doesn't apply" do
      changeset = create(:changeset, payload: {
        changes: [
          {
            action: 'destroy',
            stop: {
              onestopId: 's-9q8yt4b-1AvHoS'
            }
          }
        ]
      })
      post :apply, id: changeset.id
      expect(response.status).to eq 400
    end
  end

  context 'POST revert' do
    pending 'write the revert functionality'
  end
end
