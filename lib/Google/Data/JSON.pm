package Google::Data::JSON;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.2');

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
    # Atom Feed/Entry
    qw(
	author category content contributor email entry feed generator 
        icon id link logo name published rights source subtitle summary 
        title updated uri
    ), 
    # Atom Service/Category Documents
    qw(
	app:accept app:categories app:collection app:service app:workspace
    ),
    # Google Data APIs
    qw(
	gd:comments gd:contactSection gd:email gd:entryLink gd:feedLink 
	gd:geoPt gd:im gd:originalEvent gd:phoneNumber gd:postalAddress 
	gd:rating gd:recurrence gd:recurrenceException gd:reminder gd:when 
	gd:where gd:who
    ),
);

our $ValueKey = '$t';

our $PrettyPrinting = 0;
$JSON::AUTOCONVERT = 0;

sub new {
    my $class = shift;
    my $stream = shift;
    my $self = bless { }, $class;
    $self->set($stream);
    $self;
}

sub set {
    my $self = shift;
    $self->{stream} = shift;
    $self->{stream} = file($self->{stream})->slurp 
	if $self->{stream} !~ /[\r\n]/ and -f $self->{stream};
    $self;
}

sub _type {
    my $self = shift;
    if (not ref $self->{stream}) {
	if ($self->{stream} =~ /^</) { return 'xml' }
	elsif ($self->{stream} =~ /^\{/) { return 'json' }
    }
    elsif (ref($self->{stream}) =~ /^XML::Atom/) { return 'atom' }
    elsif (ref $self->{stream} eq 'HASH') { return 'obj' }
}

sub AUTOLOAD {
    my $self = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*:://;
    if (my ($to) = $method =~ /(?:as|to)(?:_)?(xml|json|atom|obj(?:ect)?)$/i) {
	$to = lc $to;
	my $from = $self->_type;
	if ($from eq $to) {
	    return $self->{stream};
	}
	else {
	    $method = $from . '_to_' . $to;
	    no strict 'refs'; ## no critic
	    return *{$method}->($self->{stream});
	}
    }
}

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

    my $obj = XMLin($xml, KeepRoot => 1, ForceArray => 0, ContentKey => $ValueKey);

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
	. XMLout($obj, KeepRoot => 1, ContentKey => $ValueKey);
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

    use Google::Data::JSON;

    ## Convert an XML feed into a JSON feed.
    $parser = Google::Data::JSON->new($xml);
    print $parser->as_json;

    ## XML elements, which are not Atom standards, should be added into 
    ## the array, before converting to an XML feed or an XML::Atom 
    ## object.
    push @Google::Data::JSON::Elements, qw( div p i gd:when gd:where );

    ## Convert a JSON feed into an XML feed.
    $parser = Google::Data::JSON->new($json);
    print $parser->as_xml;

    ## Convert an XML::Atom object into a JSON feed.
    print $parser->set($atom)->as_json;

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

=head2 new($stream)

Creates a new parser object from I<$stream>, such as XML and JSON,
and returns the new Google::Data::JSON object.
On failure, return "undef";

I<$stream> can be any one of the following:

=over 4

=item A filename

A filename of XML or JSON.

=item A string of XML or JSON

A string containing XML or JSON.

=item An XML::Atom object

An XML::Atom object, such as XML::Atom::Feed, XML::Atom::Entry, 
XML::Atom::Service, and XML::Atom::Categories.

=item A perl object

A perl object, that is reference to a data structure, like HASH and ARRAY.

=back

=head2 set($stream)

Sets new stream I<$stream>, such as XML and JSON,
and returns I<$self>.

=head2 as_xml

Converts into a string of XML.

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 as_json

Converts into a string of JSON.

=head2 as_atom

Converts into an XML::Atom object.

XML elements, which are not Atom standards, should be added into the array 
@Google::Data::JSON::Elements, before converting to an XML feed or an 
XML::Atom object.

=head2 as_obj

Converts into a perl object.

=head2 xml_to_json($xml)

=head2 xml_to_atom($xml)

=head2 xml_to_obj($xml)

=head2 json_to_xml($json)

=head2 json_to_atom($json)

=head2 json_to_obj($json)

=head2 atom_to_xml($atom)

=head2 atom_to_json($atom)

=head2 atom_to_obj($atom)

=head2 obj_to_xml($obj)

=head2 obj_to_json($obj)

=head2 obj_to_atom($obj)

=head2 _type

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
