#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 20;
use Test::NoWarnings;
use Google::Data::JSON qw( gdata );

my $gdata = gdata('t/samples/feed.atom');
isa_ok $gdata, 'Google::Data::JSON';

my $atom = $gdata->as_atom;
is $atom->title, 'Test Feed';
my @entries = $atom->entries;
is $entries[0]->title, 'Test Entry 1';
is $entries[1]->title, 'Test Entry 2';

my $hash = $gdata->as_hash;
is $hash->{feed}{title}{'$t'}, 'Test Feed';
is $hash->{feed}{entry}[0]{title}{'$t'}, 'Test Entry 1';
is $hash->{feed}{entry}[1]{title}{'$t'}, 'Test Entry 2';

my $json = $gdata->as_json;
like $json, qr{"title":\{"\$t":"Test Feed"\}};
like $json, qr{"title":\{"\$t":"Test Entry 1"\}};
like $json, qr{"title":\{"\$t":"Test Entry 2"\}};

$gdata = gdata('t/samples/feed.json');

$hash = $gdata->as_hash;
is $hash->{feed}{title}{'$t'}, 'Test Feed';
is $hash->{feed}{entry}[0]{title}{'$t'}, 'Test Entry 1';
is $hash->{feed}{entry}[1]{title}{'$t'}, 'Test Entry 2';

my $xml = $gdata->as_xml;
like $xml, qr{<title>Test Feed</title>};
like $xml, qr{<title>Test Entry 1</title>};
like $xml, qr{<title>Test Entry 1</title>};

$atom = $gdata->as_atom;
TODO: { 
    local $TODO = 'XML::Atom has a bug?';
    is $atom->title, 'Test Feed';
}
@entries = $atom->entries;
is $entries[0]->title, 'Test Entry 1';
is $entries[1]->title, 'Test Entry 2';
