use strict;

my $warncount = 0;

local $SIG{__DIE__} = sub {$warncount++;};

my $result = eval(qq{
die 'a';
    a = b;
    c = breakage;
});

print "warnings: $warncount\n";
