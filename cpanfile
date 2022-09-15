on 'test' => sub {
    requires 'Test::Exception', '== 0.43'
}

on 'runtime' => sub {
    requires 'Parser::MGC', '== 0.19';
    requires 'Feature::Compat::Try', '== 0.04';
    requires 'Regexp::Common', '== 2017060201';
    requires 'Net::OpenSSH', '== 0.82';
    requires 'Schedule::Cron', '== 1.01';
    requires 'Array::Utils', '== 0.5';
}