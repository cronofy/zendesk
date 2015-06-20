require 'rails_helper'
include SpecUtilities

RSpec.describe EventTracker, :type => :model do
  describe "#delete_event?" do

    let(:event_id) { random_string }

    subject { EventTracker.delete_event?(event_id) }

    context "has already been deleted" do
      before(:each) do
        EventTracker.track_delete(event_id)
      end

      it "should be false" do
        expect(subject).to be_falsey
      end
    end

    context "has already been updated" do
      before(:each) do
        EventTracker.track_update(event_id)
      end

      it "should be true" do
        expect(subject).to be_truthy
      end
    end

    context "has never been deleted" do
      it "should be true" do
        expect(subject).to be_truthy
      end
    end

    context "has never been updated" do
      it "should be true" do
        expect(subject).to be_truthy
      end
    end

    context "has been deleted and then updated" do
      before(:each) do
        EventTracker.track_delete(event_id)
        EventTracker.track_update(event_id)
      end

      it "should be true" do
        expect(subject).to be_truthy
      end
    end

  end
end