#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';
use Path::Class;
use Google::Data::JSON qw( :all );

push @Google::Data::JSON::Elements, qw( div p i );

my $json = xml_to_json('t/samples/feed.xml');
is $json, file('t/samples/feed.json')->slurp;

my $xml = json_to_xml($json);
like $xml, qr{<title type="text">dive into mark</title>};
like $xml, qr{<foaf:homepage rdf:resource="http://www.example.org/blog" />};

my $obj1 = json_to_obj($json);
my $obj2 = xml_to_obj($xml);
is_deeply $obj1, $obj2;

my $atom = obj_to_atom($obj1);
isa_ok $atom, 'XML::Atom::Feed';
is $atom->id, 'tag:example.org,2003:3';
my @entry = $atom->entries;
like $entry[0]->content->body, qr{<p>\s*<i>\[Update: The Atom draft is finished\.\]</i>\s*</p>};

$obj1 = atom_to_obj($atom);
is_deeply $obj1, $obj2;
