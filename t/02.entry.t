#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';
use File::Slurp;
use Google::Data::JSON qw( gdata add_elements );

add_elements( qw( ex:tag ) );

my $hash = {
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

my $xml = gdata($hash)->as_xml;
is $xml, read_file('t/samples/entry.xml');
