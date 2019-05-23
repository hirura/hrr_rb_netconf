# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Datastore do
  describe "#oper_proc" do
    let(:db){ 'db' }
    let(:datastore){ described_class.new db }

    it "saves operation with specified operation name" do
      datastore.oper_proc('operation'){ |arg| arg }
      expect(datastore.oper_proc('operation').call(db)).to eq db
    end
  end

  describe "#run" do
    let(:ds_session){ ds.new_session session }

    after :example do
      ds_session.close
    end

    describe "without block" do
      let(:db){ 'db' }
      let(:session){ 'session' }
      let(:ds){
        _ds = described_class.new(db)
        _ds.oper_proc('get'){ |db, input|
          ['get', db, input].join('-')
        }
        _ds
      }

      it "runs operation with db and input args" do
        expect(ds_session.run('get', 'input1')).to eq ['get', db, 'input1'].join('-')
        expect { ds_session.close }.not_to raise_error
      end
    end

    describe "with block" do
      let(:db){ StringIO.new('db') }
      let(:session){ 'session' }
      let(:ds){
        _ds = described_class.new(db){ |db, session, oper_handler|
          begin
            db_session = [db.string, session].join('-')
            oper_handler.start db_session, session
          ensure
            db.reopen('closed')
          end
        }
        _ds.oper_proc('get'){ |db_session, session, input|
          ['get', db_session, session, input].join('-')
        }
        _ds
      }

      it "runs operation with args at oper_handler.start and then calls ensure block" do
        expect(ds_session.run('get', 'input1')).to eq ['get', [db.string, session].join('-'), session, 'input1'].join('-')
        ds_session.close
        expect(db.string).to eq 'closed'
      end
    end
  end
end
