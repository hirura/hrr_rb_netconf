# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Filter::Subtree do
  let(:filter){ described_class }

  let(:filter_e){ REXML::Document.new(filter_str, {:ignore_whitespace_nodes => :all}).root }
  let(:input_e){ REXML::Document.new(input_str, {:ignore_whitespace_nodes => :all}).root }
  let(:output_e){ REXML::Document.new(output_str, {:ignore_whitespace_nodes => :all}).root }

  describe 'Namespace Selection' do
    let(:filter_str){ <<-'EOB'
      <top xmlns="http://example.com/schema/1.2/config"/>
      EOB
    }

    describe 'Totally match' do
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <child />
        </top>
        EOB
      }
      let(:output_str){ input_str }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe 'Totally unmatch' do
      let(:input_str){ <<-'EOB'
        <top xmlns="other">
          <child />
        </top>
        EOB
      }
      let(:output_str){ "" }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe 'Partially match with other global namespace' do
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <child>
            <othernamespace xmlns="other">
            </othernamespace>
          </child>
        </top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <child />
        </top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe 'Partially match with prefixed namespaces' do
      let(:input_str){ <<-'EOB'
        <top:top xmlns:top="http://example.com/schema/1.2/config" xmlns:other="other">
          <top:child>
            <other:othernamespace>
            </other:othernamespace>
          </top:child>
        </top:top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <top:top xmlns:top="http://example.com/schema/1.2/config" xmlns:other="other">
          <top:child />
        </top:top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe 'Namespace wildcard' do
      let(:filter_str){ <<-'EOB'
        <top xmlns=""/>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <child>
            <othernamespace xmlns="other">
            </othernamespace>
          </child>
        </top>
        EOB
      }
      let(:output_str){ input_str
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end
  end

  describe 'Attribute Match Expressions' do
    describe "Attribute with namespace" do
      let(:filter_str){ <<-'EOB'
        <t:top xmlns:t="http://example.com/schema/1.2/config">
          <t:interfaces>
            <t:interface t:ifName="eth0"/>
          </t:interfaces>
        </t:top>
        EOB
      }

      describe "Match" do
        let(:input_str){ <<-'EOB'
          <t:top xmlns:t="http://example.com/schema/1.2/config">
            <t:interfaces>
              <t:interface t:ifName="eth0">
                <t:child />
              </t:interface>
            </t:interfaces>
          </t:top>
          EOB
        }
        let(:output_str){ input_str }

        it "outputs matched XML" do
          expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
        end
      end

      describe "Unmatch" do
        let(:input_str){ <<-'EOB'
          <t:top xmlns:t="http://example.com/schema/1.2/config">
            <t:interfaces>
              <t:interface t:ifName="other">
                <t:child />
              </t:interface>
            </t:interfaces>
          </t:top>
          EOB
        }
        let(:output_str){ <<-'EOB'
          <t:top xmlns:t="http://example.com/schema/1.2/config">
            <t:interfaces>
            </t:interfaces>
          </t:top>
          EOB
        }

        it "outputs matched XML" do
          expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
        end
      end
    end
  end

  describe 'Containment Nodes' do
    let(:filter_str){ <<-'EOB'
      <top xmlns="http://example.com/schema/1.2/config">
        <child />
      </top>
      EOB
    }

    let(:input_str){ <<-'EOB'
      <top xmlns="http://example.com/schema/1.2/config">
        <child />
      </top>
      EOB
    }
    let(:output_str){ input_str }

    it "outputs matched XML" do
      expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
    end
  end

  describe 'Selection Nodes' do
    let(:filter_str){ <<-'EOB'
      <top xmlns="http://example.com/schema/1.2/config">
        <child />
      </top>
      EOB
    }

    let(:input_str){ <<-'EOB'
      <top xmlns="http://example.com/schema/1.2/config">
        <child />
      </top>
      EOB
    }
    let(:output_str){ input_str }

    it "outputs matched XML" do
      expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
    end
  end

  describe 'Content Match Nodes' do
    describe 'Single content match node' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <children>
            <child>
              <name>foo</name>
            </child>
          </children>
        </top>
        EOB
      }

      describe "Match" do
        let(:input_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
              <child>
                <name>foo</name>
                <bar>baz</bar>
                <properties>
                  <property>property</property>
                </properties>
              </child>
              <child>
                <name>hoge</name>
                <fuga>piyo</fuga>
                <properties>
                  <property>property</property>
                </properties>
              </child>
            </children>
          </top>
          EOB
        }
        let(:output_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
              <child>
                <name>foo</name>
                <bar>baz</bar>
                <properties>
                  <property>property</property>
                </properties>
              </child>
            </children>
          </top>
          EOB
        }

        it "outputs matched XML" do
          expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
        end
      end

      describe "Unmatch" do
        let(:input_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
              <child>
                <name>unmatch</name>
                <bar>baz</bar>
                <properties>
                  <property>property</property>
                </properties>
              </child>
              <child>
                <name>hoge</name>
                <fuga>piyo</fuga>
                <properties>
                  <property>property</property>
                </properties>
              </child>
            </children>
          </top>
          EOB
        }
        let(:output_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
            </children>
          </top>
          EOB
        }

        it "outputs matched XML" do
          expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
        end
      end
    end

    describe 'Multiple content match nodes' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <children>
            <child>
              <name>foo</name>
              <bar>baz</bar>
            </child>
          </children>
        </top>
        EOB
      }

      describe "Match" do
        let(:input_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
              <child>
                <name>foo</name>
                <bar>baz</bar>
                <properties>
                  <property>property</property>
                </properties>
              </child>
              <child>
                <name>hoge</name>
                <fuga>piyo</fuga>
                <properties>
                  <property>property</property>
                </properties>
              </child>
            </children>
          </top>
          EOB
        }
        let(:output_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
              <child>
                <name>foo</name>
                <bar>baz</bar>
                <properties>
                  <property>property</property>
                </properties>
              </child>
            </children>
          </top>
          EOB
        }

        it "outputs matched XML" do
          expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
        end
      end

      describe "Unmatch" do
        let(:input_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
              <child>
                <name>unmatch</name>
                <bar>baz</bar>
                <properties>
                  <property>property</property>
                </properties>
              </child>
              <child>
                <name>hoge</name>
                <fuga>piyo</fuga>
                <properties>
                  <property>property</property>
                </properties>
              </child>
            </children>
          </top>
          EOB
        }
        let(:output_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <children>
            </children>
          </top>
          EOB
        }

        it "outputs matched XML" do
          expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
        end
      end
    end
  end

  describe '6.4.  Subtree Filtering Examples' do
    describe '6.4.1.  No Filter' do
      it "doesn't care" do
        expect(true).to be true
      end
    end

    describe '6.4.2.  Empty Filter' do
      let(:filter_str){ '' }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config" />
        EOB
      }
      let(:output_str){ '' }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe '6.4.3.  Select the Entire <users> Subtree' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users/>
        </top>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type>superuser</type>
              <full-name>Charlie Root</full-name>
              <company-info>
                <dept>1</dept>
                <id>1</id>
              </company-info>
            </user>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
              <company-info>
                <dept>2</dept>
                <id>2</id>
              </company-info>
            </user>
            <user>
              <name>barney</name>
              <type>admin</type>
              <full-name>Barney Rubble</full-name>
              <company-info>
                <dept>2</dept>
                <id>3</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }
      let(:output_str){ input_str }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end

      describe 'the container <users> defines one child element (<user>)' do
        let(:filter_str){ <<-'EOB'
          <top xmlns="http://example.com/schema/1.2/config">
            <users>
              <user/>
            </users>
          </top>
          EOB
        }

        it "outputs matched XML" do
          expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
        end
      end
    end

    describe '6.4.4.  Select All <name> Elements within the <users> Subtree' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name/>
            </user>
          </users>
        </top>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type>superuser</type>
              <full-name>Charlie Root</full-name>
              <company-info>
                <dept>1</dept>
                <id>1</id>
              </company-info>
            </user>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
              <company-info>
                <dept>2</dept>
                <id>2</id>
              </company-info>
            </user>
            <user>
              <name>barney</name>
              <type>admin</type>
              <full-name>Barney Rubble</full-name>
              <company-info>
                <dept>2</dept>
                <id>3</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
            </user>
            <user>
              <name>fred</name>
            </user>
            <user>
              <name>barney</name>
            </user>
          </users>
        </top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe '6.4.5.  One Specific <user> Entry' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>fred</name>
            </user>
          </users>
        </top>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type>superuser</type>
              <full-name>Charlie Root</full-name>
              <company-info>
                <dept>1</dept>
                <id>1</id>
              </company-info>
            </user>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
              <company-info>
                <dept>2</dept>
                <id>2</id>
              </company-info>
            </user>
            <user>
              <name>barney</name>
              <type>admin</type>
              <full-name>Barney Rubble</full-name>
              <company-info>
                <dept>2</dept>
                <id>3</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
              <company-info>
                <dept>2</dept>
                <id>2</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe '6.4.6.  Specific Elements from a Specific <user> Entry' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>fred</name>
              <type/>
              <full-name/>
            </user>
          </users>
        </top>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type>superuser</type>
              <full-name>Charlie Root</full-name>
              <company-info>
                <dept>1</dept>
                <id>1</id>
              </company-info>
            </user>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
              <company-info>
                <dept>2</dept>
                <id>2</id>
              </company-info>
            </user>
            <user>
              <name>barney</name>
              <type>admin</type>
              <full-name>Barney Rubble</full-name>
              <company-info>
                <dept>2</dept>
                <id>3</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
            </user>
          </users>
        </top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe '6.4.7.  Multiple Subtrees' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <company-info/>
            </user>
            <user>
              <name>fred</name>
              <company-info>
                <id/>
              </company-info>
            </user>
            <user>
              <name>barney</name>
              <type>superuser</type>
              <company-info>
                <dept/>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type>superuser</type>
              <full-name>Charlie Root</full-name>
              <company-info>
                <dept>1</dept>
                <id>1</id>
              </company-info>
            </user>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
              <company-info>
                <dept>2</dept>
                <id>2</id>
              </company-info>
            </user>
            <user>
              <name>barney</name>
              <type>admin</type>
              <full-name>Barney Rubble</full-name>
              <company-info>
                <dept>2</dept>
                <id>3</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <company-info>
                <dept>1</dept>
                <id>1</id>
              </company-info>
            </user>
            <user>
              <name>fred</name>
              <company-info>
                <id>2</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end

    describe '6.4.8.  Elements with Attribute Naming' do
      let(:filter_str){ <<-'EOB'
        <t:top xmlns:t="http://example.com/schema/1.2/stats">
          <t:interfaces>
            <t:interface t:ifName="eth0"/>
          </t:interfaces>
        </t:top>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <t:top xmlns:t="http://example.com/schema/1.2/stats">
          <t:interfaces>
            <t:interface t:ifName="eth0">
              <t:ifInOctets>45621</t:ifInOctets>
              <t:ifOutOctets>774344</t:ifOutOctets>
            </t:interface>
            <t:interface t:ifName="eth1">
              <t:ifInOctets>123</t:ifInOctets>
              <t:ifOutOctets>456</t:ifOutOctets>
            </t:interface>
          </t:interfaces>
        </t:top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <t:top xmlns:t="http://example.com/schema/1.2/stats">
          <t:interfaces>
            <t:interface t:ifName="eth0">
              <t:ifInOctets>45621</t:ifInOctets>
              <t:ifOutOctets>774344</t:ifOutOctets>
            </t:interface>
          </t:interfaces>
        </t:top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end
  end

  describe 'Other conditions' do
    describe 'Data instances are not duplicated' do
      let(:filter_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type></type>
            </user>
            <user>
              <name></name>
              <type>superuser</type>
            </user>
          </users>
        </top>
        EOB
      }
      let(:input_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type>superuser</type>
              <full-name>Charlie Root</full-name>
              <company-info>
                <dept>1</dept>
                <id>1</id>
              </company-info>
            </user>
            <user>
              <name>fred</name>
              <type>admin</type>
              <full-name>Fred Flintstone</full-name>
              <company-info>
                <dept>2</dept>
                <id>2</id>
              </company-info>
            </user>
            <user>
              <name>barney</name>
              <type>admin</type>
              <full-name>Barney Rubble</full-name>
              <company-info>
                <dept>2</dept>
                <id>3</id>
              </company-info>
            </user>
          </users>
        </top>
        EOB
      }
      let(:output_str){ <<-'EOB'
        <top xmlns="http://example.com/schema/1.2/config">
          <users>
            <user>
              <name>root</name>
              <type>superuser</type>
            </user>
          </users>
        </top>
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end
  end
end
