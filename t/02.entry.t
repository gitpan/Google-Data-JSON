#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';
use Path::Class;
use Google::Data::JSON;

push @Google::Data::JSON::Elements, qw( ex:tag );

my $obj = {
    entry => {
	'xmlns:ex' => 'http://example.com/',
	title => 'My Entry',
	id => 'tag:example.org,2007:2',
	updated => '2007-02-20T23:29:59Z',
	category => {
	    scheme => 'http://example.com/',
	    term => 'hello',
	},
	content => {
	    type => 'application/xml',
	    'ex:tag' => 'Hello, World!',
	},
    },
};

my $xml = Google::Data::JSON->new($obj)->as_xml;
is $xml, file('t/samples/entry.xml')->slurp;
