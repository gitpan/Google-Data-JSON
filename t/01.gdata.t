#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 49;
use Test::NoWarnings;
use Google::Data::JSON qw( gdata );

## From XML

my $gdata = gdata('t/samples/feed.atom');
isa_ok $gdata, 'Google::Data::JSON';

my $atom = $gdata->as_atom;
is $atom->title, 'Test Feed';
my @entries = $atom->entries;
is $entries[0]->title, 'Test Entry 1';
is $entries[1]->title, 'Test Entry 2';

my $hash = gdata('t/samples/feed.atom')->as_hash;
is $hash->{feed}{title}{'$t'}, 'Test Feed';
is $hash->{feed}{'openSearch$startIndex'}{'$t'}, '1';
is $hash->{feed}{entry}[0]{title}{'$t'}, 'Test Entry 1';
is $hash->{feed}{entry}[1]{title}{'$t'}, 'Test Entry 2';

my $json = gdata('t/samples/feed.atom')->as_json;
like $json, qr{"title":\{"\$t":"Test Feed"\}};
like $json, qr{"openSearch\$startIndex":\{"\$t":"1"\}};
like $json, qr{"title":\{"\$t":"Test Entry 1"\}};
like $json, qr{"title":\{"\$t":"Test Entry 2"\}};


## From XML::Atom object

my $xml = gdata($atom)->as_xml;
like $xml, qr{<title>Test Feed</title>};
like $xml, qr{<openSearch:startIndex>1</openSearch:startIndex>};
like $xml, qr{<title>Test Entry 1</title>};
like $xml, qr{<title>Test Entry 1</title>};

$hash = gdata($atom)->as_hash;
is $hash->{feed}{title}{'$t'}, 'Test Feed';
is $hash->{feed}{'openSearch$startIndex'}{'$t'}, '1';
is $hash->{feed}{entry}[0]{title}{'$t'}, 'Test Entry 1';
is $hash->{feed}{entry}[1]{title}{'$t'}, 'Test Entry 2';

$json = gdata($atom)->as_json;
like $json, qr{"title":\{"\$t":"Test Feed"\}};
like $json, qr{"openSearch\$startIndex":\{"\$t":"1"\}};
like $json, qr{"title":\{"\$t":"Test Entry 1"\}};
like $json, qr{"title":\{"\$t":"Test Entry 2"\}};


## From JSON

$hash = gdata('t/samples/feed.json')->as_hash;
is $hash->{feed}{title}{'$t'}, 'Test Feed';
is $hash->{feed}{'openSearch$startIndex'}{'$t'}, '1';
is $hash->{feed}{entry}[0]{title}{'$t'}, 'Test Entry 1';
is $hash->{feed}{entry}[1]{title}{'$t'}, 'Test Entry 2';

$xml = gdata('t/samples/feed.json')->as_xml;
like $xml, qr{<title>Test Feed</title>};
like $xml, qr{<openSearch:startIndex>1</openSearch:startIndex>};
like $xml, qr{<title>Test Entry 1</title>};
like $xml, qr{<title>Test Entry 1</title>};

$atom = gdata('t/samples/feed.json')->as_atom;
#TODO: { 
#    local $TODO = 'XML::Atom has a bug?';
    is $atom->title, 'Test Feed';
#}
@entries = $atom->entries;
is $entries[0]->title, 'Test Entry 1';
is $entries[1]->title, 'Test Entry 2';


## From Perl HASH

$json = gdata($hash)->as_json;
like $json, qr{"title":\{"\$t":"Test Feed"\}};
like $json, qr{"openSearch\$startIndex":\{"\$t":"1"\}};
like $json, qr{"title":\{"\$t":"Test Entry 1"\}};
like $json, qr{"title":\{"\$t":"Test Entry 2"\}};

$xml = gdata($hash)->as_xml;
like $xml, qr{<title>Test Feed</title>};
like $xml, qr{<openSearch:startIndex>1</openSearch:startIndex>};
like $xml, qr{<title>Test Entry 1</title>};
like $xml, qr{<title>Test Entry 1</title>};

$atom = gdata($hash)->as_atom;
#TODO: { 
#    local $TODO = 'XML::Atom has a bug?';
    is $atom->title, 'Test Feed';
#}
@entries = $atom->entries;
is $entries[0]->title, 'Test Entry 1';
is $entries[1]->title, 'Test Entry 2';


## Non-DWIM constructors

$hash = Google::Data::JSON->new(xml => 't/samples/feed.atom')->as_hash;
is $hash->{feed}{title}{'$t'}, 'Test Feed';

$hash = Google::Data::JSON->new(json => 't/samples/feed.json')->as_hash;
is $hash->{feed}{title}{'$t'}, 'Test Feed';
