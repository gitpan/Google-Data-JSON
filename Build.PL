use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Google::Data::JSON',
    license             => 'perl',
    dist_author         => 'Takeru INOUE <takeru.inoue@gmail.com>',
    dist_version_from   => 'lib/Google/Data/JSON.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
        'XML::Atom' => 0,
        'XML::Simple' => 0,
        'JSON' => 0,
        'Storable' => 0,
        'Path::Class' => 0,
        'UNIVERSAL::require' => 0,
        'Test::NoWarnings' => 0,
        'Test::Perl::Critic' => 0,
    },
    add_to_cleanup      => [ 'Google-Data-JSON-*' ],
);

$builder->create_build_script();
