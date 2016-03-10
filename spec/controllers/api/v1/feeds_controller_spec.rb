describe Api::V1::FeedsController do
  context 'GET index' do
    context 'as JSON' do
      it 'returns all Feeds when no parameters provided' do
        create_list(:feed, 2)
        get :index, total: true
        expect_json_types({ feeds: :array })
        expect_json({
          feeds: -> (feeds) {
            expect(feeds.length).to eq 2
          },
          meta: {
            total: 2
          }
        })
      end

      it 'filters by Onestop ID' do
        create_list(:feed, 3)
        onestop_id = Feed.second.onestop_id
        get :index, onestop_id: onestop_id
        expect_json_types({ feeds: :array })
        expect_json({
          feeds: -> (feeds) {
            expect(feeds.first[:onestop_id]).to eq onestop_id
          }
        })
      end
    end
  end

  context 'as GeoJSON' do
    it 'should return GeoJSON for all feeds' do
      create_list(:feed, 2, geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [-71.04819, 42.254056],
            [-70.9016389,42.254056],
            [-70.9016389,42.359837],
            [-71.04819,42.359837],
            [-71.04819,42.254056]
          ]
        ]
      })

      get :index, format: :geojson
      expect_json({
        type: 'FeatureCollection',
        features: -> (features) {
          expect(features.map {|f| f[:properties][:onestop_id] }).to match_array(Feed.pluck(:onestop_id))
        }
      })
    end
  end

  context 'GET fetch_info' do
    pending 'a spec in the future'
  end
end
