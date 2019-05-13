# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Filter::Xpath do
  let(:filter){ described_class }

  let(:filter_e){ REXML::Document.new(filter_str, {:ignore_whitespace_nodes => :all}).root }
  let(:input_e){ REXML::Document.new(input_str, {:ignore_whitespace_nodes => :all}).root }
  let(:output_e){ REXML::Document.new(output_str, {:ignore_whitespace_nodes => :all}).root }

  describe "Without select attribute" do
    let(:filter_str){ '<filter type="xpath" />' }
    let(:input_str){ <<-'EOB'
      <top xmlns="http://example.com/schema/1.2/config" />
      EOB
    }

    it "raises missing-attribute error" do
      expect { described_class.filter(input_e, filter_e) }.to raise_error HrrRbNetconf::Server::Error['missing-attribute']
    end
  end

  describe 'Empty Filter' do
    let(:filter_str){ '<filter type="xpath" select="" />' }
    let(:input_str){ <<-'EOB'
      <top xmlns="http://example.com/schema/1.2/config" />
      EOB
    }
    let(:output_str){ input_str }

    it "outputs matched XML" do
      expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
    end
  end

  describe 'Select the Entire <users> Subtree' do
    let(:filter_str){ <<-'EOB'
      <filter xmlns="http://example.com/schema/1.2/config" type="xpath" select="/top/users" />
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
        <filter xmlns="http://example.com/schema/1.2/config" type="xpath" select="/top/users/user" />
        EOB
      }

      it "outputs matched XML" do
        expect(described_class.filter(input_e, filter_e).to_s).to eq output_e.to_s
      end
    end
  end

  describe 'Select All <name> Elements within the <users> Subtree' do
    let(:filter_str){ <<-'EOB'
      <filter xmlns="http://example.com/schema/1.2/config" type="xpath" select="/top/users/user/name" />
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

  describe 'Specific <user> Entry' do
    let(:filter_str){ <<-'EOB'
      <filter xmlns="http://example.com/schema/1.2/config" type="xpath" select="/top/users/user[name='fred']" />
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

  describe 'Specific Elements from a Specific <user> Entry' do
    let(:filter_str){ <<-'EOB'
      <filter xmlns="http://example.com/schema/1.2/config" type="xpath" select="/top/users/user[name='fred']/name | /top/users/user[name='fred']/type | /top/users/user[name='fred']/full-name" />
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

  describe 'Multiple Subtrees' do
    let(:filter_str){ <<-'EOB'
      <filter xmlns="http://example.com/schema/1.2/config" type="xpath" select="/top/users/user[name='root']/name | /top/users/user[name='root']/company-info | /top/users/user[name='fred']/name | /top/users/user[name='fred']/company-info/id | /top/users/user[name='barney' and type='superuser']/name | /top/users/user[name='barney' and type='superuser']/type | /top/users/user[name='barney' and type='superuser']/company-info/dept" />
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

  describe 'Elements with Attribute Naming' do
    let(:filter_str){ <<-'EOB'
      <filter xmlns:t="http://example.com/schema/1.2/stats" type="xpath" select="/t:top/t:interfaces/t:interface[@t:ifName='eth0']" />
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

  describe 'Data instances are not duplicated' do
    let(:filter_str){ <<-'EOB'
      <filter xmlns="http://example.com/schema/1.2/config" type="xpath" select="/top/users/user[name='root']/name | /top/users/user[name='root']/type | /top/users/user[type='superuser']/name | /top/users/user[type='superuser']/type" />
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
