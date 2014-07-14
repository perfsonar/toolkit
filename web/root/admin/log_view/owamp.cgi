#!/usr/bin/perl
use strict;

use FindBin qw($RealBin);

#include perfsonar library
use lib ("$RealBin/../lib");
use Template;
use CGI qw(:standard);
use HTML::Entities;
use POSIX;
use Socket;
use Data::Validate::IP qw(is_ipv4 is_ipv6);

my $cgi = new CGI;
print $cgi->header;

my $basedir     = "$RealBin/";
my $templatedir = "$basedir/templates";
my $configdir   = "$basedir/etc";

#open template
my $tt = Template->new( INCLUDE_PATH => "$templatedir" ) or die("Couldn't initialize template toolkit");

my $html;

my %vars = ();
$vars{"owamp_data_present"} = 0;

my @summary = ();
my @data = ();
my @entry = ();

my %domains = ();
my $domaincount = 0;

my $log_dir = "/var/lib/perfsonar/log_view/owamp/";
my @logs = ();

opendir(DIR, $log_dir) or die "can't open $log_dir\n";
while ( my $file = readdir( DIR ) ) {
    next unless ( $file =~ m/^owamp/ );
    push @logs, $file;
}
closedir( DIR );

my %lookup = ();

foreach my $l ( reverse sort @logs ) {

    if ( $l =~ /\.gz$/ ) {
	open( LOGFILE, "gunzip -c $log_dir.$l |" ) or die "can't open pipe to $log_dir.$l\n";
    }
    else {
	open( LOGFILE, $log_dir.$l ) or die "can't open $log_dir.$l\n";
    }

    while( <LOGFILE> ) {
	chomp;	

	next unless $_ =~ m/.*owampd.*Connection.*/;
	next if $_ =~ m/.*reset.*/;

	$vars{"owamp_data_present"} = 1;

	my @output = ();
        
	@entry = split( / /, $_ );
	my @sentry = ();

	if ( $#entry == 12 and not $entry[1]) {
	    # covers the case of an extra space in the date (e.g. "Sept 30" vs "Oct  1")
	    @sentry = @entry[0,2..$#entry];
	    @entry = @sentry;
	}

	if ( $#entry == 12 ) {
	    my $cnt = 0;
	    foreach my $e ( @entry ) {
		delete $entry[$cnt] unless $e;
		$cnt++;
	    }
	}

	push @output, $entry[0] . " " . $entry[1] . " " . $entry[2] . " " . strftime("%Z", localtime());

	$entry[11] =~ s/\(//g;
	$entry[11] =~ s/\)//g;
	$entry[11] =~ s/\[//g;
	$entry[11] =~ s/\].*//g;

	if ( is_ipv6 ( $entry[11] ) ) {
	    push @output, $entry[11];
	    push @output, $entry[11];

	    $domains{"?"}++;		
	}
	elsif( is_ipv4 ( $entry[11] ) ) {
	    push @output, $entry[11];

	    my $hst = 0;
	    if ( defined $lookup{$entry[11]} ) {
		$hst = $lookup{$entry[11]};
	    }
	    else {
		$hst = scalar gethostbyaddr( inet_aton( $entry[11] ), AF_INET );
		$lookup{$entry[11]} = $hst;
	    }

	    if ( defined $hst and not ( $hst =~ m/in-addr\.arpa/g ) ) {
		push @output, $hst;

		my @dmn = split(/\./, $hst);
		my $tld = pop(@dmn);
		my $bd = pop(@dmn);

		if ( $tld and $bd ) {
		    $domains{join("\.", ( $bd, $tld ) )}++;
		}
		else {
		    $domains{"?"}++;
		}
	    }
	    else {
		push @output, $entry[11];
		$domains{"?"}++;
	    }
	}
	else {
	    my $packed_ip = 0;
	    if ( defined $lookup{$entry[11]} ) {
		$packed_ip = $lookup{$entry[11]};
	    }
	    else {
		$packed_ip = gethostbyname( $entry[11] );
		$lookup{$entry[11]} = $packed_ip;
	    }

	    if (defined $packed_ip) {
		push @output, inet_ntoa( $packed_ip );
	    }
	    else {
		push @output, $entry[11];
	    }
	    
	    push @output, $entry[11];
	    my @dmn = split( /\./, $entry[11] );
	    my $tld = pop(@dmn);
	    my $bd = pop(@dmn);
	    if ( $tld and $bd ) {
		$domains{join("\.", ( $bd, $tld ) )}++;
	    }
	    else {
		$domains{"?"}++;
	    }
	}
	$domaincount++;

	push @data, \@output;
    }
    close( LOGFILE ); 
}

my $domaincount2 = 0;
foreach my $d ( sort keys %domains ) {
    my @row = ();
    push @row, $d;
    push @row, $domains{$d};
    push @summary, \@row;
    $domaincount2++;
}

$vars{"owamp_summary"} = \@summary;
$vars{"owamp_data"} = \@data;
$vars{"owamp_totalt"} = $domaincount;
$vars{"owamp_totald"} = $domaincount2;

$tt->process( "log_view_owamp.tmpl", \%vars, \$html ) or die $tt->error();

print $html;

exit 0;
