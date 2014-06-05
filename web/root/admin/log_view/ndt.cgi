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
$vars{"ndt_data_present"} = 0;

my @summary = ();
my @data = ();

my %domains = ();
my $domaincount = 0;

my $log_dir = "/var/lib/perfsonar/log_view/ndt/";
my @logs = ();

opendir(DIR, $log_dir) or die "can't open $log_dir\n";
while ( my $file = readdir( DIR ) ) {
    next unless ( $file =~ m/^ndt/ );
    push @logs, $file;
}
closedir( DIR );

my %lookup = ();

my $count = 0;
foreach my $l ( reverse sort @logs ) {
    
    last if ($count++ > 3);
    
    if ( $l =~ /\.gz$/ ) {
	open( LOGFILE, "gunzip -c $log_dir.$l |" ) or die "can't open pipe to $log_dir.$l\n";
    }
    else {
	open( LOGFILE, $log_dir.$l ) or die "can't open $log_dir.$l\n";
    }

    while( <LOGFILE> ) {
	chomp;	
	next unless $_ =~ m/.*web100srv:\ client_IP.*/;
	$vars{"ndt_data_present"} = 1;
	
	my @output = ();

	my @entry = split( / /, $_ );
	my @sentry = ();

	if ( $#entry == 6 and not $entry[1] ) {
	    # covers the case of an extra space in the date (e.g. "Sept 30" vs "Oct  1")
	    @sentry = @entry[0,2..$#entry];
	    @entry = @sentry;
	}

	if ( $#entry == 6 ) {
	    my $cnt	= 0;
	    foreach my $e ( @entry ) {
		delete $entry[$cnt] unless $e;
		$cnt++;
	    }
	}

	push @output, $entry[0] . " " . $entry[1] . " " . $entry[2] . " " . strftime("%Z", localtime());	
	my @variables = split( /,/, $entry[5] );

	$variables[0] =~ s/client_IP=//;

	if ( is_ipv6 ( $variables[0] ) ) {
	    push @output, $variables[0];
	    push @output, $variables[0];

	    $domains{"?"}++;		
	}
	elsif( is_ipv4 ( $variables[0] ) ) {
	    push @output, $variables[0];

	    my $hst = 0;
	    if ( defined $lookup{$variables[0]} ) {
		$hst = $lookup{$variables[0]};
	    }
	    else {
		$hst = scalar gethostbyaddr( inet_aton( $variables[0] ), AF_INET );
		$lookup{$variables[0]} = $hst;
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
		push @output, $variables[0];
		$domains{"?"}++;
	    }
	}
	else {
	    my $packed_ip = 0;
	    if ( defined $lookup{$variables[0]} ) {
		$packed_ip = $lookup{$variables[0]};
	    }
	    else {
		$packed_ip = gethostbyname( $variables[0] );
		$lookup{$variables[0]} = $packed_ip;
	    }

	    if (defined $packed_ip) {
		push @output, inet_ntoa( $packed_ip );
	    }
	    else {
		push @output, $variables[0];
	    }

	    push @output, $variables[0];

	    my @dmn = split( /\./, $variables[0] );
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

$vars{"ndt_summary"} = \@summary;
$vars{"ndt_data"} = \@data;
$vars{"ndt_totalt"} = $domaincount;
$vars{"ndt_totald"} = $domaincount2;

$tt->process( "log_view_ndt.tmpl", \%vars, \$html ) or die $tt->error();

print $html;

exit 0;
