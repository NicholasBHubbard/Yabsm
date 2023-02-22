# Only list dependencies not in v5.34.0 core

requires 'Array::Utils'   => '0.5';
requires 'IPC::Run3'      => '0.048';
requires 'Net::OpenSSH'   => '0.83';
requires 'Parser::MGC'    => '0.21';
requires 'Regexp::Common' => '2017060201';
requires 'Schedule::Cron' => '1.04';

on 'test' => sub {
   requires 'Test::Exception' => '0';
};
