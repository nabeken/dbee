# vim:fileencoding=utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/job'

describe 'DBEE Encode::Config' do
  before(:all) do
    @preset = DBEE::Config::Encode::PRESET.dup
    DBEE::Config::Encode::PRESET.replace 'preset'

    @program_id = DBEE::Config::Encode::PROGRAM_ID.dup
    DBEE::Config::Encode::PROGRAM_ID[/TOKYOMX/] = '99999'
    @get_cmd_format = "-y -i \"%s\" -f mp4 -vcodec libx264 -vsync 1 -fpre %s " +
                      "-r 30000/1001 -s %s -aspect 16:9 -bufsize 14000k -maxrate 2500k " +
                      "-acodec libfaac -ar 48000 -ac 2 -ab 128k -async 1 " +
                      "-threads %s"
    Facter.stub(:processorcount).and_return('PPP')
  end

  def get_new_config
    config = DBEE::Job::Encode::Config.new
    config.source = 'source-TOKYOMX.ts'
    config.size = 'XXXXxYYYY'
    config
  end

  after(:all) do
    DBEE::Config::Encode::PRESET.replace @preset
    DBEE::Config::Encode::PROGRAM_ID.delete(/TOKYOMX/)
  end

  it 'says get_cmd' do
    get_cmd_format = @get_cmd_format.dup
    get_cmd_format << " -programid %s"
    config = get_new_config
    config.get_cmd.should == (get_cmd_format % %w(source-TOKYOMX.ts preset XXXXxYYYY PPP 99999))
  end

  it 'says get_cmd in FreeBSD' do
    Facter.stub(:kernel).and_return('FreeBSD')
    get_cmd_format = @get_cmd_format.dup
    get_cmd_format << " -programid %s"
    config = get_new_config
    config.stub(:`).and_return('FBSD')
    config.get_cmd.should == (get_cmd_format % %w(source-TOKYOMX.ts preset XXXXxYYYY FBSD 99999))
  end

  it 'says @program_id is empty when there is no PROGRAM_ID matches' do
    Facter.stub(:kernel).and_return('Linux')
    config = get_new_config
    config.source = 'TOKYOFX.ts'
    config.get_programid.should be_nil
    get_cmd_format = @get_cmd_format.dup
    config.get_cmd.should == (get_cmd_format % %w(TOKYOFX.ts preset XXXXxYYYY PPP))
  end
end
