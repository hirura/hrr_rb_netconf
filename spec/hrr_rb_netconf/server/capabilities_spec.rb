# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Capabilities do
  describe '#initialize' do
    describe "without features" do
      let(:capabilities){ described_class.new }

      it "has a list of Capability" do
        expect( capabilities.instance_variable_get('@caps').keys ).to eq HrrRbNetconf::Server::Capability.list
      end
    end

    describe "with features" do
      let(:features){ [] }
      let(:capabilities){ described_class.new }

      it "also has a list of Capability" do
        expect( capabilities.instance_variable_get('@caps').keys ).to eq HrrRbNetconf::Server::Capability.list
      end
    end
  end

  describe "#register_capability" do
    let(:capabilities){ described_class.new }
    let(:cap_proc){ Proc.new{ |cap| } }

    it "registers capability proc" do
      capabilities.register_capability('cap1', &cap_proc)
      expect( capabilities.instance_variable_get('@caps').has_key?('cap1') ).to be true
    end
  end

  describe "#unregister_capability" do
    let(:capabilities){ described_class.new }
    let(:cap_proc){ Proc.new{ |cap| } }

    it "unregisters capability proc" do
      capabilities.register_capability('cap1', &cap_proc)
      capabilities.unregister_capability('cap1')
      expect( capabilities.instance_variable_get('@caps').has_key?('cap1') ).to be false
    end
  end

  describe "#list_supported" do
    let(:capabilities){ described_class.new features }

    describe "with empty features" do
      let(:features){ [] }

      it "returns capabilities that has no if-features list" do
        expect( capabilities.list_supported ).to eq HrrRbNetconf::Server::Capability.list.select{ |c| HrrRbNetconf::Server::Capability[c].new.if_features.empty? }
      end
    end

    describe "with specific features" do
      let(:features){ ['test1', 'test2'] }

      it "returns capabilities that has no if-features list and that has 'test1' or 'test2' if-features" do
        capabilities.register_capability('cap1'){ |cap| cap.if_features = ['test1'] }
        capabilities.register_capability('cap2'){ |cap| cap.if_features = ['test2'] }
        capabilities.register_capability('cap3'){ |cap| cap.if_features = ['test3'] }
        expect( capabilities.list_supported ).to eq (HrrRbNetconf::Server::Capability.list.select{ |c| (HrrRbNetconf::Server::Capability[c].new.if_features - features).empty? } + ['cap1', 'cap2'])
      end
    end
  end

  describe "#list_loadable" do
    let(:capabilities){ described_class.new }

    describe "with no cyclic dependencies" do
      it "returns capability list that is loadable order" do
        capabilities.instance_variable_get('@caps').clear
        capabilities.register_capability('cap3'){ |cap| cap.dependencies = ['cap2'] }
        capabilities.register_capability('cap2'){ |cap| cap.dependencies = ['cap1'] }
        capabilities.register_capability('cap1'){ |cap| cap.dependencies = [] }
        expect( capabilities.list_loadable ).to eq ['cap1', 'cap2', 'cap3']
      end
    end

    describe "with cyclic dependencies" do
      it "raises TSort::Cyclic error" do
        capabilities.instance_variable_get('@caps').clear
        capabilities.register_capability('cap3'){ |cap| cap.dependencies = ['cap2'] }
        capabilities.register_capability('cap2'){ |cap| cap.dependencies = ['cap1'] }
        capabilities.register_capability('cap1'){ |cap| cap.dependencies = ['cap3'] }
        expect { capabilities.list_loadable }.to raise_error TSort::Cyclic
      end
    end
  end

  describe "#negotiate" do
    let(:capabilities){ described_class.new features }

    describe "when features is nil" do
      let(:features){ nil }

      describe "when capabilities which are pre-configured" do
        before :example do
          Class.new(HrrRbNetconf::Server::Capability){ |klass|
            klass::ID = 'urn:cap:with:queries:1.0'
            klass::QUERIES = {'scheme' => ['http', 'https']}
          }
        end

        after :example do
          HrrRbNetconf::Server::Capability.instance_variable_get('@subclass_list').delete('url:cap:with:queries:1.0')
        end

        describe "with exact matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,https',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:ietf:params:netconf:capability:startup:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http', 'https']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http%2Chttps'
          end
        end

        describe "with partial matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:ietf:params:netconf:capability:startup:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http'
          end
        end

        describe "with no matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:ietf:params:netconf:capability:startup:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0'
          end
        end
      end

      describe "when capabilities which are dynamically configured" do
        before :example do
          capabilities.register_capability('urn:cap:with:queries:1.0'){ |cap|
            cap.queries = {'scheme' => ['http', 'https']}
          }
        end

        describe "with exact matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,https',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:ietf:params:netconf:capability:startup:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http', 'https']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http%2Chttps'
          end
        end

        describe "with partial matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:ietf:params:netconf:capability:startup:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http'
          end
        end

        describe "with no matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:ietf:params:netconf:capability:startup:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0'
          end
        end
      end
    end

    describe "when empty features" do
      let(:features){ [] }

      describe "when capabilities which are pre-configured" do
        before :example do
          Class.new(HrrRbNetconf::Server::Capability){ |klass|
            klass::ID = 'urn:cap:with:queries:1.0'
            klass::QUERIES = {'scheme' => ['http', 'https']}
          }
        end

        after :example do
          HrrRbNetconf::Server::Capability.instance_variable_get('@subclass_list').delete('url:cap:with:queries:1.0')
        end

        describe "with exact matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,https',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http', 'https']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http%2Chttps'
          end
        end

        describe "with partial matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http'
          end
        end

        describe "with no matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0'
          end
        end
      end

      describe "when capabilities which are dynamically configured" do
        before :example do
          capabilities.register_capability('urn:cap:with:queries:1.0'){ |cap|
            cap.queries = {'scheme' => ['http', 'https']}
          }
        end

        describe "with exact matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,https',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http', 'https']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http%2Chttps'
          end
        end

        describe "with partial matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=http,ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({'scheme' => ['http']})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0?scheme=http'
          end
        end

        describe "with no matched remote capabilities" do
          let(:remote_capabilities){
            [
              'urn:ietf:params:netconf:capability:startup:1.0',
              'urn:cap:with:queries:1.0?scheme=ftp',
            ]
          }

          it "returns negotiated capabilities" do
            negotiated_capabilities = capabilities.negotiate remote_capabilities
            expect(negotiated_capabilities.instance_variable_get('@caps').has_key? 'urn:cap:with:queries:1.0').to be true
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].queries).to eq ({})
            expect(negotiated_capabilities.instance_variable_get('@caps')['urn:cap:with:queries:1.0'].id).to eq 'urn:cap:with:queries:1.0'
          end
        end
      end
    end
  end
end
