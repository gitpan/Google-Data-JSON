package Google::Data::JSON;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.3');

use XML::Simple;
use JSON;
use List::MoreUtils qw( any uniq );
use File::Slurp;
use Perl6::Export::Attrs;
use UNIVERSAL::require;

# XML::Simple
our $ContentKey     = '$t';

# JSON
our $PrettyPrinting = 0;
$JSON::AUTOCONVERT  = 0;

my @atom_elements = qw(
    author category content contributor email entry feed generator icon id link
    logo name published rights source subtitle summary title updated uri
);

my @app_elements = qw(
    accept categories collection service workspace
);

my @gd_elements = qw(
    attendeeStatus attendeeType comments contactSection email entryLink 
    feedLink geoPt im originalEvent phoneNumber postalAddress rating recurrence
     recurrenceException reminder when where who
);

my @opensearch_elements = qw(
    totalResults startIndex itemsPerPage
);

@atom_elements         = map { ( $_, "atom:$_"         ) } @atom_elements;
@app_elements          = map { ( $_, "app:$_"          ) } @app_elements;
@gd_elements           = map { ( $_, "gd:$_"           ) } @gd_elements;
@opensearch_elements   = map { ( $_, "openSearch:$_"   ) } @opensearch_elements;

my @Elements
    = ( @atom_elements, @app_elements, @gd_elements, @opensearch_elements );

sub new {
    my $class  = shift;
    my $stream = shift;

    $stream = read_file($stream) if $stream !~ /[\r\n]/ && -f $stream;

    my $data = do {
	no strict 'refs'; ## no critic
         *{ _type_of($stream) . '_to_hash' }->( $stream );
    };

    return bless { data => $data }, $class;
}

sub gdata :Export { __PACKAGE__->new(@_) }

sub as_xml  { hash_to_xml ( shift->{data} ) }
sub as_json { hash_to_json( shift->{data} ) }
sub as_atom { hash_to_atom( shift->{data} ) }
sub as_hash { shift->{data}                }

sub add_elements :Export {
    croak "This is class method" if ref $_[0];

    push @Elements, @_;
    return @Elements = uniq @Elements;
}

sub get_elements :Export {
    croak "This is class method" if ref $_[0];

    return @Elements;
}

sub _type_of {
    my $stream = shift;

    if (not ref $stream) {
        return $stream =~ /\A </xms  ? 'xml'
             : $stream =~ /\A \{/xms ? 'json'
             :                          croak "Bad stream: $stream" ;
    }
    else {
        return ref($stream) =~ /\AXML::Atom/ ? 'atom'
             : ref $stream eq 'HASH'         ? 'hash'
             :                                  croak "Bad stream: $stream";
    }
}

sub _is_element {
    my ($key) = @_;

    my %is_element = map { ($_ => 1) } @Elements;
    return $is_element{$key};
}

sub _fix_keys_of {
    my ($data, $converting_to_json) = @_;

    my ($from, $to) = $converting_to_json ? (':',  '$')
                    :                       ('\$', ':') ;

    if (ref $data eq 'HASH') {
	for my $key (keys(%{ $data })) {
	    if ($key =~ m{\A [^$from]+ $from .+ \z}xms) {
		my $original = $key;
		$key =~ s{$from}{$to};
		$data->{$key} = $data->{$original};
		delete $data->{$original};
	    }

	    $data->{$key} = _fix_keys_of( $data->{$key}, $converting_to_json )
		if ref $data->{$key};
	}
    }
    elsif (ref $data eq 'ARRAY') {
	for my $element (@{ $data }) {
	    $element = _fix_keys_of( $element, $converting_to_json )
		if ref $element eq 'HASH';
	}
    }

    return $data;
}

sub _force_array {
    my ($data) = @_;

    if (ref $data eq 'HASH') {
	for my $key ( keys(%{ $data }) ) {
	    $data->{$key} = _force_array($data->{$key}) if ref $data->{$key};

	    if (ref $data->{$key} ne 'ARRAY' && _is_element($key)) {
		$data->{$key} = [ $data->{$key} ];
	    }
	}
    }
    elsif (ref $data eq 'ARRAY') {
	for my $element (@{ $data }) {
	    $element = _force_array($element) if ref $element eq 'HASH';
	}
    }

    return $data;
}

sub _alleviate_array {
    my ($data) = @_;

    if (ref $data eq 'HASH') {
	for my $key ( keys(%{ $data }) ) {
	    $data->{$key} = _alleviate_array($data->{$key}) if ref $data->{$key};
	}
    }
    elsif (ref $data eq 'ARRAY') {
	if (ref $data eq 'ARRAY' && @{ $data } == 1) {
	    $data = _alleviate_array($data->[0]);
	}
	else {
	    for my $element (@{ $data }) {
		$element = _alleviate_array($element) if ref $element eq 'HASH';
	    }
	}
    }

    return $data;
}

sub xml_to_json :Export {
    return hash_to_json( xml_to_hash(shift) );
}

sub xml_to_atom :Export {
    my $xml    = shift;

    my ($root) = $xml =~ /<\?xml [^>]+? \?> \s*? <(\w+) /xms;
    my $module = 'XML::Atom::' . ucfirst($root);
    $module->require || croak $@;

    return $module->new(\$xml);
}

sub xml_to_hash :Export {
    my $xml = shift;

    $xml = read_file($xml) unless $xml =~ /^<\?xml/;

    $xml =~ m{^
                <\? xml [^>]+?
                    version=["']([\d\.]+)["'] [^>]+?      #'
                    (?:encoding=["']([^"']+)["'])? [^>]*? #"
                \?>
             }xms;
    my ($version, $encoding) = ($1, $2);

    my $data = XMLin(
        $xml,
        KeepRoot   => 1,
        ForceArray => 0,
        ContentKey => $ContentKey,
    );

    $data->{version}  = $version  if defined $version;
    $data->{encoding} = $encoding if defined $encoding;

    return $data;
}

sub json_to_xml :Export {
    return hash_to_xml( json_to_hash(shift) );
}

sub json_to_atom :Export {
    return xml_to_atom( json_to_xml(shift) );
}

sub json_to_hash :Export {
    return _fix_keys_of( jsonToObj(shift), 0 );
}

sub atom_to_xml :Export {
    return shift->as_xml;
}

sub atom_to_json :Export {
    return xml_to_json( atom_to_xml(shift) );
}

sub atom_to_hash :Export {
    return xml_to_hash( atom_to_xml(shift) );
}

sub hash_to_xml :Export {
    my $data = shift;

    my $version  = $data->{version}  || 1.0;
    my $encoding = $data->{encoding} || 'utf-8';
    delete $data->{version};
    delete $data->{encoding};

    $data = _force_array($data);

    my $xml = "<?xml version=\"$version\" encoding=\"$encoding\"?>\n"
        . XMLout($data, KeepRoot => 1, ContentKey => $ContentKey);

    $data = _alleviate_array($data);

    return $xml;
}

sub hash_to_json :Export {
    return objToJson(
        _fix_keys_of( shift, 1 ),
        { pretty => $PrettyPrinting, indent => 2 }
    );
}

sub hash_to_atom :Export {
    return xml_to_atom( hash_to_xml(shift) );
}

*hash_to_hash = \&_alleviate_array;

1; # Magic true value required at end of module
__END__

=head1 NAME

Google::Data::JSON - XML-JSON converter based on Google Data APIs


=head1 SYNOPSIS

    use Google::Data::JSON qw( gdata add_elements );

    ## Convert an XML feed into a JSON feed.
    $parser = Google::Data::JSON->new($xml);
    print $parser->as_json;

    ## XML elements, which are not Atom/GData standards, should be
    ## added into the array by using Google::Data::JSON::add_elements,
    ## before converting to an XML feed or an XML::Atom object.
    add_elements( qw( div p i ex:tag ) );

    ## Convert a JSON feed into an XML feed.
    print Google::Data::JSON->new($json)->as_xml;

    ## gdata() is a shortcut for Google::Data::JSON->new()
    print gdata($atom)->as_json;

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


=head1 METHODS

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

=item A Perl hash

A Perl hash, strictly saying, that is a reference to a data structure, like
HASH and ARRAY.

=back

=head2 gdata($stream)

Shortcut for Google::Data::JSON->new() .

=head2 as_xml

Converts into a string of XML.

XML elements, which are not Atom/GData standards, should be added into the
array by using Google::Data::JSON::add_elements, before converting to an XML
feed or an XML::Atom object.

=head2 as_json

Converts into a string of JSON.

=head2 as_atom

Converts into an XML::Atom object.

XML elements, which are not Atom/GData standards, should be added into the
array by using Google::Data::JSON::add_elements, before converting to an XML
feed or an XML::Atom object.

=head2 as_hash

Converts into a Perl hash.

=head2 add_elements(@elements)

Adds a list of elements name, which are recognized as XML elements not
attributes in converting.

=head2 get_elements

Returns a list of elements name, which are recognized as XML elements not
attributes in converting.

=head2 xml_to_json($xml)

=head2 xml_to_atom($xml)

=head2 xml_to_hash($xml)

=head2 json_to_xml($json)

=head2 json_to_atom($json)

=head2 json_to_hash($json)

=head2 atom_to_xml($atom)

=head2 atom_to_json($atom)

=head2 atom_to_hash($atom)

=head2 hash_to_xml($hash)

=head2 hash_to_json($hash)

=head2 hash_to_atom($hash)

=head2 hash_to_hash($hash)

Extracts array references that have just one element.

=head2 _type_of

=head2 _is_element

=head2 _fix_keys_of

=head2 _force_array

=head2 _alleviate_array

=head1 EXPORT

None by default.

=head1 EXAMPLE OF FEEDS

The following example shows XML, JSON and Perl hash versions of the 
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

=head2 Perl hash

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

Takeru INOUE  C<< <takeru.inoue _ gmail.com> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Takeru INOUE C<< <takeru.inoue _ gmail.com> >>. All rights reserved.

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

=cut
