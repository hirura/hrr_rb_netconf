# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::RelaxedXML do
  describe "XML" do
    describe "when instantiated with no args" do
      it "can take element name argument and store it as element" do
        xml = described_class.new
        root_e = xml.add_element 'root'
        expect( xml.elements[1].name ).to eq 'root'
      end

      it "can take element name argument multiple times and store them as elements" do
        xml = described_class.new
        root1_e = xml.add_element 'root1'
        root2_e = xml.add_element 'root2'
        root3_e = xml.add_element 'root3'
        expect( xml.elements[1].name ).to eq 'root1'
        expect( xml.elements[2].name ).to eq 'root2'
        expect( xml.elements[3].name ).to eq 'root3'
      end
    end

    describe "when instantiated with XML string" do
      it "can take one root element" do
        xml = described_class.new <<-EOB
          <root>
            <dummy />
          </root>
        EOB
        expect( xml.elements[1].name ).to eq 'root'
      end

      it "can take multiple root elements" do
        xml = described_class.new <<-EOB
          <root1>
            <dummy1 />
          </root1>
          <root2>
            <dummy2 />
          </root2>
          <root3>
            <dummy3 />
          </root3>
        EOB
        expect( xml.elements[1].name ).to eq 'root1'
        expect( xml.elements[2].name ).to eq 'root2'
        expect( xml.elements[3].name ).to eq 'root3'
      end
    end
  end

  describe "XPath" do
    let(:xml){ described_class.new xml_str }
    let(:xml_str){
      <<-EOB
        <a1 id='1'>
          <b1 id='2' x='y'>
            <c1 id='3'/>
            <c1 id='4'/>
          </b1>
          <d1 id='5'>
            <c1 id='6' x='y'/>
            <c1 id='7'/>
            <c1 id='8'/>
            <q1 id='19'/>
          </d1>
        </a1>
        <a2 id='1'>
          <b2 id='2' x='y'>
            <c2 id='3'/>
            <c2 id='4'/>
          </b2>
          <d2 id='5'>
            <c2 id='6' x='y'/>
            <c2 id='7'/>
            <c2 id='8'/>
            <q2 id='19'/>
          </d2>
        </a2>
        <a3 id='1'>
          <b3 id='2' x='y'>
            <c3 id='3'/>
            <c3 id='4'/>
          </b3>
          <d3 id='5'>
            <c3 id='6' x='y'/>
            <c3 id='7'/>
            <c3 id='8'/>
            <q3 id='19'/>
          </d3>
        </a3>
      EOB
    }

    describe "when every node under root node" do
      let(:xpath){ '/*' }

      it "matches all root elements" do
        expect(described_class::XPath.match(xml, xpath).map{|e| e.name}).to eq ["a1", "a2", "a3"]
      end
    end

    describe "when context node is under an root element and move to another root element" do
      let(:xpath){ '/a1/../a2' }

      it "matches target node" do
        expect(described_class::XPath.match(xml, xpath).map{|e| e.name}).to eq ["a2"]
      end
    end

    describe "when selecting by attributes on every root element" do
      let(:xpath){ '/*[@id="1"]' }

      it "matches all root elements which have the attribute" do
        expect(described_class::XPath.match(xml, xpath).map{|e| e.name}).to eq ["a1", "a2", "a3"]
      end
    end
  end
end
