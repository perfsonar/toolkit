package perfSONAR_PS::Web::Sidebar;

#our $VERSION = 3.3; # what to do here?

use strict;
use warnings;

use Time::HiRes qw( time );
#use Log::Log4perl qw(get_logger :easy :levels);
use Params::Validate;
use Data::Dumper;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;
use perfSONAR_PS::NPToolkit::Config::ExternalAddress;

use Exporter qw(import);
our @EXPORT_OK = qw(set_sidebar_vars);

our ( $administrative_info_conf );

$administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
$administrative_info_conf->init();

sub set_sidebar_vars {

    #my ( $self, @params ) = @_;
     
    #my $parameters = validate( @params, { vars => 0 } );
    my $parameters = validate( @_, { vars => 1 } );
    my $vars = $parameters->{vars};

    my $start = [Time::HiRes::gettimeofday()];

    #$administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();

    if (!$administrative_info_conf->is_complete()) {
        $vars->{admin_info_nav_class} = "warning";
    }

    my $diff = Time::HiRes::tv_interval($start);
    warn "time: $diff\n";
    return $vars;

}

1;
