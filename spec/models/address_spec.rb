require 'rails_helper'

describe Address do
  it "has a valid factory" do
    expect(build(:address)).to be_valid
  end

  context 'schema' do
    it {should have_db_column(:latitude).of_type(:float) }
    it {should have_db_column(:longitude).of_type(:float) }
    it {should have_db_column(:street_1).of_type(:string) }
    it {should have_db_column(:street_2).of_type(:string) }
    it {should have_db_column(:city).of_type(:string) }
    it {should have_db_column(:state_code).of_type(:string) }
    it {should have_db_column(:zip_code).of_type(:string) }
    it {should have_db_column(:visited_at).of_type(:datetime) }
    it {should have_db_column(:most_supportive_resident_id).of_type(:integer) }
    it {should have_db_column(:usps_verified_street_1).of_type(:string) }
    it {should have_db_column(:usps_verified_city).of_type(:string) }
    it {should have_db_column(:usps_verified_zip).of_type(:string) }
    it {should have_db_column(:best_canvass_response).of_type(:string).with_options(default: "not_yet_visited") }
    it {should have_db_column(:last_canvass_response).of_type(:string).with_options(default: "unknown") }
  end

  context 'associations' do
    it { should have_many(:people) }
    it { should belong_to(:most_supportive_resident) }
  end

  context 'validations' do
    it { should validate_presence_of(:state_code) }
  end

  context 'scopes' do
    it "has a working 'within' scope" do
      first_address_in_radius = create(:address, latitude: 1, longitude: 1)
      second_address_in_radius = create(:address, latitude: -1, longitude: -1)
      third_address_outside_radius = create(:address, latitude: 20, longitude: 20)

      addresses_in_radius = Address.within(400 * 1000, origin: [0, 0]) # 400 km distance
      expect(addresses_in_radius).to include(first_address_in_radius)
      expect(addresses_in_radius).to include(second_address_in_radius)
      expect(addresses_in_radius).not_to include(third_address_outside_radius)
    end
  end

  it "has a working 'best_canvass_response' enum" do
    address = create(:address)

    expect(address.best_is_not_yet_visited?).to be true

    address.best_is_not_home!
    expect(address.best_is_not_home?).to be true

    address.best_is_unknown!
    expect(address.best_is_unknown?).to be true

    address.best_is_strongly_for!
    expect(address.best_is_strongly_for?).to be true

    address.best_is_leaning_for!
    expect(address.best_is_leaning_for?).to be true

    address.best_is_undecided!
    expect(address.best_is_undecided?).to be true

    address.best_is_leaning_against!
    expect(address.best_is_leaning_against?).to be true

    address.best_is_strongly_against!
    expect(address.best_is_strongly_against?).to be true

    address.best_is_asked_to_leave!
    expect(address.best_is_asked_to_leave?).to be true
  end

  it "has a working 'last_canvass_response' enum" do
    address = create(:address)

    expect(address.last_is_unknown?).to be true

    address.last_is_not_yet_visited!
    expect(address.last_is_not_yet_visited?).to be true

    address.last_is_not_home!
    expect(address.last_is_not_home?).to be true

    address.last_is_strongly_for!
    expect(address.last_is_strongly_for?).to be true

    address.last_is_leaning_for!
    expect(address.last_is_leaning_for?).to be true

    address.last_is_undecided!
    expect(address.last_is_undecided?).to be true

    address.last_is_leaning_against!
    expect(address.last_is_leaning_against?).to be true

    address.last_is_strongly_against!
    expect(address.last_is_strongly_against?).to be true

    address.last_is_asked_to_leave!
    expect(address.last_is_asked_to_leave?).to be true
  end

  describe "instance methods" do

    describe "#assign_most_supportive_resident" do
      before do
        @person = create(:person, canvass_response: "leaning_for")
        other_person_1 = create(:person, canvass_response: "leaning_against")
        other_person_2 = create(:person, canvass_response: "strongly_against")

        @address = create(:address,
          most_supportive_resident: @person,
          best_canvass_response: @person.canvass_response,
          people: [@person, other_person_1, other_person_2])
      end

      context "when a different person is being assigned" do

        context "and it has a higher 'canvass_response' than the current 'most_supportive_resident'" do
          it "assigns them as the 'most_supportive_resident'" do
            new_person = create(:person, canvass_response: "strongly_for")

            @address.assign_most_supportive_resident(new_person)

            expect(@address.most_supportive_resident).to eq new_person
            expect(@address.best_is_strongly_for?).to be true
          end
        end

        context "and it has a lower 'canvass_response' than the current 'most_supportive_resident'" do
          it "keeps the old 'most_supportive_resident'" do
            new_person = create(:person, canvass_response: "leaning_against")
            @address.assign_most_supportive_resident(new_person)

            expect(@address.most_supportive_resident).not_to be new_person
            expect(@address.best_is_leaning_against?).to be false
          end
        end
      end

      context "when an existing person changes their canvass_response" do

        context "when the new response is higher" do
          it "updates best_canvass_response, keeps the same person" do
            @person.strongly_for!
            @address.assign_most_supportive_resident(@person)

            expect(@address.most_supportive_resident).to eq @person
            expect(@address.best_is_strongly_for?).to be true
          end
        end

        context "when the new response is lower" do
          context "when the person still has the highest canvass_response" do
            it "updates best_canvass_response, keeps the same person" do
              @person.undecided!
              @address.assign_most_supportive_resident(@person)

              expect(@address.most_supportive_resident).to eq @person
              expect(@address.best_is_undecided?).to be true
            end
          end

          context "when another person now has the highest canvass_response" do
            it "updates best_canvass_response and the person" do
              @person.strongly_against!
              @address.assign_most_supportive_resident(@person)

              expect(@address.most_supportive_resident).not_to eq @person
              expect(@address.best_is_leaning_against?).to be true
            end
          end
        end
      end
    end

    describe "#recently_visited?" do
      it "returns true if the address has been visited within a time span" do
        address = create(:address, recently_visited?: true)
        expect(address.reload.recently_visited?).to be true
      end
      it "returns false if the address has not been visited within a time span" do
        address = create(:address, recently_visited?: false)
        expect(address.reload.recently_visited?).to be false
      end
    end
  end

  describe "class methods" do
    describe ".new_or_existing_from_params" do
      it "initializes a new address if the params do not contain an id", vcr: { cassette_name: "models/address/creates_a_new_address_if_the_params_do_not_contain_an_id" } do
        expect(Address.count).to eq 0
        params = { latitude: 1, longitude: 1 }
        address = Address.new_or_existing_from_params(params)
        expect(address.persisted?).to be false
      end

      it "fetches and updates (without save) an existing address if the params do contain an id" do
        create(:address, id: 1, latitude: 0, longitude: 0)
        params = { id: 1, latitude: 1, longitude: 1 }
        address = Address.new_or_existing_from_params(params)
        expect(Address.count).to eq 1
        expect(address.changed?).to be true
        expect(address.latitude).to eq 1
        expect(address.longitude).to eq 1
      end

      it "throws an error if updating the same address twice in a short period" do
        address = create(:address, id: 1, recently_visited?: true)
        params = { id: 1, latitude: 1, longitude: 1 }
        expect { Address.new_or_existing_from_params(params) }.to raise_error GroundGame::VisitNotAllowed
      end
    end

    it "should raise an error if there's an invalid 'best_canvass_response' parameter value" do
      create(:address, id: 1, latitude: 0, longitude: 0)
      params = {
        id: 1,
        best_canvass_response: "strongly_for"
      }
      expect { Address.new_or_existing_from_params(params) }.to raise_error ArgumentError
    end
  end
end
