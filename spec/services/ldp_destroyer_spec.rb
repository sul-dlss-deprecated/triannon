require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

vcr_options = {:re_record_interval => 45.days}  # TODO will make shorter once we have jetty running fedora4
describe Triannon::LdpDestroyer, :vcr => vcr_options do

  describe "#destroy" do

    let(:anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl") }
    let(:conn) { Faraday.new(:url => Triannon.config[:ldp_url]) }

    it "deletes the resource from the LDP store" do
      svc = Triannon::LdpCreator.new anno
      new_pid = svc.create_base

      Triannon::LdpDestroyer.destroy new_pid
      resp = conn.get do |req|
        req.url "#{new_pid}"
      end
      expect(resp.status).to eq 410
    end

    it "raises an exception if the delete does not succeed" do
      expect { Triannon::LdpDestroyer.destroy 'junkpid' }.to raise_error(/Unable to delete Annotation: junkpid/)
    end
  end

end
