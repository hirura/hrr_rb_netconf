# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Capability::Base_1_1 do
  let(:id){ 'urn:ietf:params:netconf:base:1.1' }
  let(:capability){ described_class.new }

  it "can be looked up in HrrRbNetconf::Server::Capability dictionary" do
    expect( HrrRbNetconf::Server::Capability[id] ).to eq described_class
  end       

  it "is registered in HrrRbNetconf::Server::Capability.list" do
    expect( HrrRbNetconf::Server::Capability.list ).to include id
  end         

  describe '::Sender' do
    let(:io_w){ StringIO.new }
    let(:sender){ described_class::Sender.new io_w }
    let(:receiver){ described_class::Receiver.new io_w }
    let(:formatter){ f = REXML::Formatters::Pretty.new(2); f.compact = true; f }
    let(:received_message){ buf = String.new; formatter.write(receiver.receive_message, buf); buf }
    let(:expecting_message){
      raw_message = [
        "<rpc message-id=\"102\"\n",
        "     xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\">\n",
        "  <close-session/>\n",
        "</rpc>",
      ].join
      expecting_xml_doc = REXML::Document.new(raw_message, {:ignore_whitespace_nodes => :all})
      buf = String.new
      formatter.write(expecting_xml_doc.root, buf)
      buf
    }

    it "sends chunked message" do
      sender.send_message expecting_message
      io_w.rewind
      expect(received_message).to eq expecting_message
    end
  end

  describe '::Receiver' do
    let(:io_r){ StringIO.new }
    let(:receiver){ described_class::Receiver.new io_r }
    let(:formatter){ f = REXML::Formatters::Pretty.new(2); f.compact = true; f }
    let(:received_message){ buf = String.new; formatter.write(receiver.receive_message, buf); buf }

    describe "when receives valid message" do
      let(:encoded_message){
        [
          "\n#4\n",
          "<rpc",
          "\n#18\n",
          " message-id=\"102\"\n",
          "\n#79\n",
          "     xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\">\n",
          "  <close-session/>\n",
          "</rpc>",
          "\n##\n",
        ].join
      }
      let(:expecting_message){
        raw_message = [
          "<rpc message-id=\"102\"\n",
          "     xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\">\n",
          "  <close-session/>\n",
          "</rpc>",
        ].join
        expecting_xml_doc = REXML::Document.new(raw_message, {:ignore_whitespace_nodes => :all})
        buf = String.new
        formatter.write(expecting_xml_doc.root, buf)
        buf
      }

      it "returns XML element" do
        io_r.reopen encoded_message
        expect(received_message).to eq expecting_message
      end
    end

    describe "when receives invalid message" do
      describe "when not begin with #{"\n".inspect} in beginning_of_msg" do
        let(:encoded_message){
          [
            "a",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when not #{"#".inspect} after #{"\n".inspect} in before_chunk_size" do
        let(:encoded_message){
          [
            "\na",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when not #{"/[0-9]/".inspect}, #{"\n".inspect}, nor #{"#".inspect} after #{"#".inspect} in in_chunk_size" do
        let(:encoded_message){
          [
            "\n#a",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when not #{"/[0-9]/".inspect}, #{"\n".inspect}, nor #{"#".inspect} after #{"/[0-9]/".inspect} in in_chunk_size" do
        let(:encoded_message){
          [
            "\n#1a",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when not #{"\n".inspect} in after_chunk_data" do
        let(:encoded_message){
          [
            "\n#1\nax",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when not #{"\n".inspect} after #{"#".inspect} in ending_msg" do
        let(:encoded_message){
          [
            "\n##x",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when not well-formed XML" do
        let(:encoded_message){
          [
            "\n#4\n",
            "<abc",
            "\n##\n",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when not well-formed XML and the length is less than 4" do
        let(:encoded_message){
          [
            "\n#1\n",
            "<",
            "\n##\n",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when the root tag is not \"rpc\"" do
        let(:encoded_message){
          [
            "\n#9\n",
            "<other />",
            "\n##\n",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when there is no namespace" do
        let(:encoded_message){
          [
            "\n#7\n",
            "<rpc />",
            "\n##\n",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end

      describe "when invalid namespace" do
        let(:encoded_message){
          [
            "\n#22\n",
            "<rpc xmlns=\"invalid\"/>",
            "\n##\n",
          ].join
        }
        it "raises Error['malformed-message']" do
          io_r.reopen encoded_message
          expect { received_message }.to raise_error HrrRbNetconf::Server::Error['malformed-message']
        end
      end
    end
  end
end
