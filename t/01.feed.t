#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';
use Path::Class;
use XML::Atom::Feed;
use Google::Data::JSON;

my $parser1 = Google::Data::JSON->new('t/samples/feed.xml');
isa_ok $parser1, 'Google::Data::JSON';

my $json = $parser1->as_json;
is $json, file('t/samples/feed.json')->slurp;

push @Google::Data::JSON::Elements, qw( div p i );

my $parser2 = Google::Data::JSON->new('t/samples/feed.json');
my $xml = $parser2->as_xml;
like $xml, qr{<title type="text">dive into mark</title>};
like $xml, qr{<foaf:homepage rdf:resource="http://www.example.org/blog" />};

my $obj1 = $parser1->set($json)->as_obj;
my $obj2 = $parser2->set($xml)->as_obj;
is_deeply $obj1, $obj2;

my $atom = $parser1->set($obj1)->as_atom;
isa_ok $atom, 'XML::Atom::Feed';
is $atom->id, 'tag:example.org,2003:3';
my @entry = $atom->entries;
like $entry[0]->content->body, qr{<p>\s*<i>\[Update: The Atom draft is finished\.\]</i>\s*</p>};

$obj1 = $parser2->set($atom)->as_obj;
is_deeply $obj1, $obj2;
