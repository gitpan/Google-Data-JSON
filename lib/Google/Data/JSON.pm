package Google::Data::JSON;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.1');

use XML::Simple;
use JSON;
use Storable;
use Path::Class;
use UNIVERSAL::require;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
    xml_to_json xml_to_atom xml_to_obj
    json_to_xml json_to_atom json_to_obj
    atom_to_xml atom_to_json atom_to_obj
    obj_to_xml obj_to_json obj_to_atom
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw( );

our @Elements = ( 
    qw( feed entry ), 
    qw( id title subtitle icon logo rights ),
    qw( link category ),
    qw( author contributor generator name email uri ),
    qw( updated published ),
    qw( content summary source ),
#    qw( service workspace collection categories accept ),
);

our $Value = '$t';

our $PrettyPrinting = 0;
$JSON::AUTOCONVERT = 0;

sub xml_to_json {
    obj_to_json(xml_to_obj(shift));
}

sub xml_to_atom {
    my $xml = shift;
    my ($root) = $xml =~ /<\?xml [^>]+? \?> \s*? <(\w+) /xm;
    my $module = 'XML::Atom::' . ucfirst($root);
    $module->require or croak $@;
    $module->new(\$xml);
}

sub xml_to_obj {
    my $xml = shift;

    $xml = file($xml)->slurp unless $xml =~ /^<\?xml/;

    $xml =~ /^<\?xml [^>]+?
	  version=["']([\d\.]+)["'] [^>]+?	#'
	  (?:encoding=["']([^"']+)["'])? [^>]*? #"
	\?>/xm;
    my $version = $1;
    my $encoding = $2;

    my $obj = XMLin($xml, KeepRoot => 1, ForceArray => 0, ContentKey => $Value);

    $obj->{version} = $version if $version;
    $obj->{encoding} = $encoding if $encoding;

    $obj;
}

sub json_to_xml {
    obj_to_xml(json_to_obj(shift));
}

sub json_to_atom {
    xml_to_atom(json_to_xml(shift));
}

sub json_to_obj {
    _fix_keys(jsonToObj(shift), 0);
}

sub atom_to_xml {
    shift->as_xml;
}

sub atom_to_json {
    xml_to_json(atom_to_xml(shift));
}

sub atom_to_obj {
    xml_to_obj(atom_to_xml(shift));
}

sub obj_to_xml {
    my $obj = shift;

    my $version = $obj->{version} || 1.0;
    my $encoding = $obj->{encoding} || 'utf-8';
    delete $obj->{version};
    delete $obj->{encoding};

    $obj = _force_array($obj);

    "<?xml version=\"$version\" encoding=\"$encoding\"?>\n"
	. XMLout($obj, KeepRoot => 1, ContentKey => $Value);
}

sub obj_to_json {
    objToJson(_fix_keys(shift, 1), { pretty => $PrettyPrinting, indent => 2 });
}

sub obj_to_atom {
    xml_to_atom(obj_to_xml(shift));
}

sub _fix_keys {
    my $obj = Storable::dclone shift;
    my $to_json = shift;

    my ($from, $to) = $to_json ? (':', '$') : ('\$', ':');

    if (ref $obj eq 'HASH') {
	for my $key (keys(%$obj)) {
	    if ($key =~ /^[-\w]+$from[-\w]+$/) {
		my $original = $key;
		$key =~ s/$from/$to/;
		$obj->{$key} = $obj->{$original};
		delete $obj->{$original};
	    }

	    $obj->{$key} = _fix_keys($obj->{$key}, $to_json)
		if ref $obj->{$key};

	    ## force array
#	    if (not $to_json and ref $obj->{$key} ne 'ARRAY' and _is_element($key)) {
#		$obj->{$key} = [ $obj->{$key} ];
#	    }
	}
    }
    elsif (ref $obj eq 'ARRAY') {
	for my $element (@{ $obj }) {
	    $element = _fix_keys($element, $to_json)
		if ref $element eq 'HASH';
	}
    }

    $obj;
}

sub _is_element {
    my $key = shift;
    my $num = grep $key eq $_, @Elements;
    $num;
}

sub _force_array {
    my $obj = Storable::dclone shift;

    if (ref $obj eq 'HASH') {
	for my $key (keys(%$obj)) {
	    $obj->{$key} = _force_array($obj->{$key}) if ref $obj->{$key};

	    if (ref $obj->{$key} ne 'ARRAY' and _is_element($key)) {
		$obj->{$key} = [ $obj->{$key} ];
	    }
	}
    }
    elsif (ref $obj eq 'ARRAY') {
	for my $element (@{ $obj }) {
	    $element = _force_array($element) if ref $element eq 'HASH';
	}
    }

    $obj;
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Google::Data::JSON - XML-JSON converter based on Google Data APIs


=head1 SYNOPSIS

    use Google::Data::JSON qw( :all );

    ## Convert an XML feed into a JSON feed.
    print xml_to_json($xml);

    ## XML elements, which are not Atom standards, should be added into 
    ## the array, before converting to an XML feed or an XML::Atom 
    ## object.
    push @Google::Data::JSON::Elements, qw( div p i gd:when gd:where );

    ## Convert a JSON feed into an XML feed.
    print json_to_xml($json);

    ## Convert an XML::Atom object into a JSON feed.
    push @Google::Data::JSON::Elements, qw( div p i gd:when gd:where );
    print atom_to_xml($atom);

=head1 DESCRIPTION

B<Google::Data::JSON> provides several methods to convert an XML feed 
into a JSON feed, and vice versa. The JSON format is defined in Google 
Data APIs, http://code.google.com/apis/gdata/json.html .

This module is not restricted to the Google Data APIs.
Any XML documents can be converted into JSON-format.

The following rules are described in Google Data APIs:

=head2 Basic

- The feed is represented as a JSON object; each nested element or attribute 
is represented as a name/value property of the object.

- Attributes are converted to String properties.

- Child elements are converted to Object properties.

- Elements that may appear more than once are converted to Array properties.

- Text values of tags are converted to $t properties.

=head2 Namespace

- If an element has a namespace alias, the alias and element are concatenated 
using "$". For example, ns:element becomes ns$element.

=head2 XML

- XML version and encoding attributes are converted to attribute version and 
encoding of the root element, respectively.


=head1 USAGE

=head2 xml_to_json($xml)

Converts an XML feed into a JSON feed.
I<$xml> can be string or file name.

=head2 xml_to_atom($xml)

Converts an XML feed into an XML::Atom object.
I<$xml> can be string or file name.

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 xml_to_obj($xml)

Converts an XML feed into a perl object.
I<$xml> can be string or file name.

=head2 json_to_xml($json)

Converts a JSON feed into an XML feed.
I<$json> must be string, which meets the Google Data APIs.

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 json_to_atom($json)

Converts a JSON feed into an XML::Atom object.
I<$json> must be string, which meets the Google Data APIs.

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 json_to_obj($json)

Converts a JSON feed into a perl object.
I<$json> must be string, which meets the Google Data APIs.

=head2 atom_to_xml($atom)

Converts an XML::Atom object into an XML feed.
I<$atom> must be an XML::Atom::Feed or XML::Atom::Entry object.

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 atom_to_json($atom)

Converts an XML::Atom object into a JSON feed.
I<$atom> must be an XML::Atom::Feed or XML::Atom::Entry object.

=head2 atom_to_obj($atom)

Converts an XML::Atom object into a perl object.
I<$atom> must be an XML::Atom::Feed or XML::Atom::Entry object.

=head2 obj_to_xml($obj)

Converts a perl object into an XML feed.
I<$obj> must be a perl object;

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 obj_to_json($obj)

Converts a perl object into a JSON feed.
I<$obj> must be a perl object;

=head2 obj_to_atom($obj)

Converts a perl object into an XML::Atom object.
I<$obj> must be a perl object;

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 _fix_keys

=head2 _is_element

=head2 _force_array


=head1 EXPORT

None by default.


=head1 EXAMPLE OF FEEDS

The following example shows XML, JSON and perl object versions of the 
same feed:

=head2 XML feed

	<?xml version="1.0" encoding="utf-8"?>
	<feed xmlns="http://www.w3.org/2005/Atom">
	  <title>dive into mark</title>
	  <id>tag:example.org,2003:3</id>
	  <updated>2005-07-31T12:29:29Z</updated>
	  <link rel="alternate" type="text/html"
	   hreflang="en" href="http://example.org/"/>
	  <link rel="self" type="application/atom+xml"
	   href="http://example.org/feed.atom"/>
	  <entry>
	    <title>Atom draft-07 snapshot</title>
	    <id>tag:example.org,2003:3.2397</id>
	    <updated>2005-07-31T12:29:29Z</updated>
	    <published>2003-12-13T08:29:29-04:00</published>
	    <link rel="alternate" type="text/html"
	     href="http://example.org/2005/04/02/atom"/>
	    <author>
	      <name>Mark Pilgrim</name>
	    </author>
	    <content type="xhtml" xml:lang="en">
	      <div xmlns="http://www.w3.org/1999/xhtml">
	        <p><i>[Update: The Atom draft is finished.]</i></p>
	      </div>
	    </content>
	  </entry>
	</feed>

=head2 JSON feed

	{
	  "version" : "1.0",
	  "encoding" : "utf-8"
	  "feed" : {
	    "xmlns" : "http://www.w3.org/2005/Atom",
	    "link" : [
	      {
	        "rel" : "alternate",
	        "href" : "http://example.org/",
	        "type" : "text/html",
	        "hreflang" : "en"
	      },
	      {
	        "rel" : "self",
	        "href" : "http://example.org/feed.atom",
	        "type" : "application/atom+xml"
	      }
	    ],
	    "entry" : {
	      "link" : {
	        "rel" : "alternate",
	        "href" : "http://example.org/2005/04/02/atom",
	        "type" : "text/html"
	      },
	      "published" : "2003-12-13T08:29:29-04:00",
	      "content" : {
	        "div" : {
	          "xmlns" : "http://www.w3.org/1999/xhtml",
	          "p" : {
	            "i" : "[Update: The Atom draft is finished.]"
	          }
	        },
	        "xml$lang" : "en",
	        "type" : "xhtml"
	      },
	      "author" : {
	        "name" : "Mark Pilgrim"
	      },
	      "updated" : "2005-07-31T12:29:29Z",
	      "id" : "tag:example.org,2003:3.2397",
	      "title" : "Atom draft-07 snapshot"
	    },
	    "title" : "dive into mark",
	    "id" : "tag:example.org,2003:3",
	    "updated" : "2005-07-31T12:29:29Z"
	  },
	}

=head2 perl object

	$VAR1 = {
	  'version' => '1.0',
	  'encoding' => 'utf-8',
	  'feed' => {
	    'link' => [
	      {
	        'rel' => 'alternate',
	        'href' => 'http://example.org/',
	        'type' => 'text/html',
	        'hreflang' => 'en'
	      },
	      {
	        'rel' => 'self',
	        'href' => 'http://example.org/feed.atom',
	        'type' => 'application/atom+xml'
	      }
	    ],
	    'xmlns' => 'http://www.w3.org/2005/Atom',
	    'entry' => {
	      'link' => {
	        'rel' => 'alternate',
	        'href' => 'http://example.org/2005/04/02/atom',
	        'type' => 'text/html'
	      },
	      'published' => '2003-12-13T08:29:29-04:00',
	      'content' => {
	        'div' => {
	          'xmlns' => 'http://www.w3.org/1999/xhtml',
	          'p' => {
	            'i' => '[Update: The Atom draft is finished.]'
	          }
	        },
	        'type' => 'xhtml',
	        'xml:lang' => 'en'
	      },
	      'author' => {
	        'name' => 'Mark Pilgrim'
	      },
	      'updated' => '2005-07-31T12:29:29Z',
	      'id' => 'tag:example.org,2003:3.2397',
	      'title' => 'Atom draft-07 snapshot'
	    },
	    'updated' => '2005-07-31T12:29:29Z',
	    'id' => 'tag:example.org,2003:3',
	    'title' => 'dive into mark'
	  },
	};
	

=head1 SEE ALSO

L<XML::Atom>


=head1 AUTHOR

Takeru INOUE  C<< <takeru.inoue@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Takeru INOUE C<< <takeru.inoue@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
