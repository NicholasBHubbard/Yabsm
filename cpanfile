# Only list dependencies not in v5.34.0 core

# Feature::Compat::Try must be version 0.04 in order for yabsm
# to support v5.34.0 as its minimum version. Feature::Compat::Try
# versions >0.04 require XS on Perl <5.36.0, which prevents us
# from fatpacking.

requires 'Array::Utils'         => '== 0.5';
requires 'Feature::Compat::Try' => '== 0.04';
requires 'IPC::Run3'            => '== 0.048';
requires 'Net::OpenSSH'         => '== 0.84';
requires 'Parser::MGC'          => '== 0.21';
requires 'Regexp::Common'       => '== 2017060201';
requires 'Schedule::Cron'       => '== 1.05';

on 'test' => sub {
   requires 'Test::Exception' => '0';
};
