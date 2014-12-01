#
#      $Id$
#
#########################################################################
#									#
#			   Copyright (C)  2002				#
#	     			Internet2				#
#			   All Rights Reserved				#
#									#
#########################################################################
#
#	File:		perfSONAR_PS::Config::OWP::Helper.pm
#
#	Author:		Jeff Boote
#			Internet2
#
#	Date:		Tue Sep 24 11:23:49  2002
#
#	Description:	
#
#	Usage:
#
#	Environment:
#
#	Files:
#
#	Options:
package perfSONAR_PS::Config::OWP::Helper;
require Exporter;
use strict;
use vars qw(@ISA @EXPORT $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw(owpverify_args print_hash split_addr);

$perfSONAR_PS::Config::OWP::REVISION = '$Id$';
$VERSION = '1.0';

sub owpverify_args{
    my($allowed,$must,%args) = @_;
    my %allowed;

    foreach (@$allowed){
        next if !defined $_;
        tr/a-z/A-Z/;
        $allowed{$_} = 1;
    }
    foreach (@$must){
        next if !defined $_;
        tr/a-z/A-Z/;
        $allowed{$_} = 1;
    }

    foreach (keys %args){
        my $name = $_;
        $name =~ tr/a-z/A-Z/;

        if(!defined($allowed{$name})){
            my($pack,$fname,$line,$sub) = caller(1);
            warn "$fname\:$line -- $pack\:\:$sub\: Invalid arg $name\n";
            return undef;
        }

        if($name ne $_){
            $args{$name} = $args{$_};
            delete $args{$_};
        }
    }

    foreach (@$must){
        next if exists $args{$_};

        my($pack,$fname,$line,$sub) = caller(1);
        warn "$fname\:$line -- $pack\:\:$sub\: Missing required arg $_\n";
        return undef;
    }

    my @args = %args;
    return @args;
}

sub print_hash{
    my($name, %hash) = @_;
    my $key;

    foreach $key (sort keys(%hash)){
        warn "\$$name\{$key\}:\t$hash{$key}\n";
    }
}

#
# XXX: unit test eventually...
# Test cases:
#   [2001:468:1:12::16:98]:8725
#   2001:468:1:12::16:98
#   [2001:468:1:12::16:98]
#   192.168.1.1
#   192.168.1.1:1234
#   [192.168.1.1]:1234
#   nonsense.org
#   nonsense.org:87632
#   nonsense.org:8763292837492847
sub split_addr{
    my ($fulladdr) = @_;

    my ($cnt,$addr,$port);

    $_ = $fulladdr;
    # any spaces is an error
    if ( ($cnt = tr/ \t\n\r\f//) > 0){
        warn "split_addr(): Address \"$fulladdr\" contains $cnt whitespace chars";
        return (undef,undef);
    }
    # full brackets
    if (($addr,$port) = /^\[([^\]]*)\]\:(\d*)$/){
        ;
    }
    # brackets - no port
    elsif (($addr) = /^\[([^\]]*)\]$/){
        ;
    }
    # no brackets, more than one ':' indicates bare v6 - no port
    elsif ( (tr/:/:/) > 1){
        $addr = $fulladdr;
    }
    # hostname with
    elsif (($addr,$port) = /^([^:]*)\:(\d*)$/){
        ;
    }
    else{
        $addr = $fulladdr;
    }

    if(defined($port)){
        if((length($port) < 1) || ($port == 0)){
            undef $port;
        }
        elsif($port > 65535){
            warn "split_addr(): Address \"$fulladdr\" specifies an invalid port value \"$port\"";
        }
    }

    return ($addr,$port);
}
