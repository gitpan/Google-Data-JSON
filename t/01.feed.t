#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';
use File::Slurp;
use XML::Atom::Feed;
use Google::Data::JSON qw( gdata add_elements xml_to_json );

my $parser = Google::Data::JSON->new('t/samples/feed.xml');
isa_ok $parser, 'Google::Data::JSON';

my $json = $parser->as_json;
is $json, read_file('t/samples/feed.json');

is xml_to_json('t/samples/feed.xml'), $json;

add_elements( qw( div p i ) );

my $xml = gdata('t/samples/feed.json')->as_xml;
like $xml, qr{<title type="text">dive into mark</title>};
like $xml, qr{<foaf:homepage rdf:resource="http://www.example.org/blog" />};

my $hashref1 = gdata($json)->as_hashref;
my $hashref2 = gdata($xml)->as_hashref;
is_deeply $hashref1, $hashref2;

my $atom = gdata($hashref1)->as_atom;
isa_ok $atom, 'XML::Atom::Feed';
is $atom->id, 'tag:example.org,2003:3';
my @entry = $atom->entries;
like $entry[0]->content->body, qr{<p>\s*<i>\[Update: The Atom draft is finished\.\]</i>\s*</p>};
