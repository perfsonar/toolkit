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
#	File:		perfSONAR_PS::Config::OWP::Conf.pm
#
#	Author:		Jeff Boote
#			Internet2
#
#	Date:		Tue Sep 24 10:40:10  2002
#
#	Description:	
#			This module is used to set configuration parameters
#			for the perfSONAR_PS::Config::OWP one-way-ping mesh configuration.
#
#			To add additional "scalar" parameters, just start
#			using them. If the new parameter is
#			a BOOL then also add it to the BOOL hash here. If the
#			new parameter is an array then add it to the ARRS
#			hash.
#
#	Usage:
#
#			my $conf = new perfSONAR_PS::Config::OWP::Conf([
#						NODE	=>	nodename,
#						CONFDIR =>	path/to/confdir,
#						])
#			NODE will default to ($node) = ($hostname =~ /^.*-(/w)/)
#			CONFDIR will default to $HOME
#
#			The config files can have sections that are
#			only relevant to a particular system/node/addr by
#			using the pseudo httpd.conf file syntax:
#
#			<OS=$regex>
#			osspecificsettings	val
#			</OS>
#
#			The names for the headings are OS and Host.
#			$regex is a text string used to match uname -s,
#			and uname -n. It can contain the wildcard
#			chars '*' and '?' with '*' matching 0 or more occurances
#			of *anything* and '?' matching exactly 1 occurance
#			of *anything*.
#
#	Environment:
#
#	Files:
#
#	Options:
package perfSONAR_PS::Config::OWP::Conf;
require Exporter;
require 5.005;
use strict;
# use POSIX;
use FindBin;
use perfSONAR_PS::Config::OWP::Helper;

$perfSONAR_PS::Config::OWP::Conf::REVISION = '$Id$';
$perfSONAR_PS::Config::OWP::Conf::VERSION='1.0';

# Eventually set using $sysconfig autoconf variable.
$perfSONAR_PS::Config::OWP::Conf::CONFPATH='~';			# default dir for config files.

$perfSONAR_PS::Config::OWP::Conf::GLOBALCONFENV='OWPGLOBALCONF';
$perfSONAR_PS::Config::OWP::Conf::DEVCONFENV='OWPCONF';
$perfSONAR_PS::Config::OWP::Conf::GLOBALCONFNAME='owmesh.conf';

#
# This hash is used to privide default values for "some" parameters.
#
my %DEFS = (
	OWAMPDPIDFILE		=>	'owampd.pid',
	OWAMPDINFOFILE		=>	'owampd.info',
	OWPBINDIR		=>	"$FindBin::Bin",
	CONFDIR			=>	"$perfSONAR_PS::Config::OWP::Conf::CONFPATH/",
);

# Opts that are arrays.
# (These options are automatically split with whitespace - and the return
# is set as an array reference. These options can also show up on more
# than one line, and the values will append onto the array.)
# (Syntax is [[val val val]] )
my %ARRS;

# Keep hash of all 'types' of sub-hashes in the config hash.
my %HASHOPTS;

sub new {
	my($class,@initialize) = @_;
	my $self = {};

	bless $self,$class;

	return $self->init(@initialize);
}

sub resolve_path{
	my($self,$path) = @_;
	my($home,$user,$key);
        my $savepath = $path;
	
	if(($path =~ m#^~/#o) || ($path =~ m#^~$#o)){
		$home = ( $ENV{"HOME"} || $ENV{"LOGDIR"} || (getpwuid($<))[7] );
                if(!defined($home)){
                    die "Unable to resolve ~ in path $savepath";
                }
		$path =~ s#^\~#$home#o;
	}
	elsif(($user) = ($path =~ m#^~([^/]+)/.*#o)){
		$home = (getpwnam($user))[7];
                if(!defined($home)){
                    die "Unable to resolve ~$user in path $savepath";
                }
		$path = $home.substr($path,length($user)+1);
	}

        while ( ($key) = ($path =~ m#\$\{([^\}]+)\}#o) ){
            if(!defined($ENV{$key})){
                die "Unable to resolve \$$key in path $savepath";
            }

	    $path =~ s/\$\{$key\}/$ENV{$key}/g;
	}

	while( ($key) = ($path =~ m#\$([^\/]+)#o) ){
            if(!defined($ENV{$key})){
                die "Unable to resolve \$$key in path $savepath";
            }

	    $path =~ s/\$$key/$ENV{$key}/g;
	}

	return $path;
}

# grok a single line from the config file, and adding that parameter
# into the hash ref passed in, unless skip is set.
sub load_line{
	my($self,$line,$href,$skip) = @_;
	my($pname,$val);

	$_ = $line;

	return 1 if(/^\s*#/); # comments
	return 1 if(/^\s*$/); # blank lines

        # reset any var
	if(($pname) = /^\!(\w+)\s+/o){
		$pname =~ tr/a-z/A-Z/;
		delete ${$href}{$pname} if(!defined($skip));
		return 1;
	}
	# bool
	if(($pname) = /^(\w+)\s*$/o){
		$pname =~ tr/a-z/A-Z/;
		${$href}{$pname} = 1 if(!defined($skip));
		return 1;
	}
	# array assignment
	if((($pname,$val) = /^(\w+)\s+\[\[(.*?)\]\]\s*$/o)){
		$_ = $val;
		$pname =~ tr/a-z/A-Z/;
		$ARRS{$pname} = 1;
		return 1 if(defined($skip));
		push @{${$href}{$pname}}, split;
		return 1;
	}
	# assignment
	if((($pname,$_) = /^(\w+)\s+(.*?)\s*$/o)){
		return 1 if(defined($skip));
		$pname =~ tr/a-z/A-Z/;
                # reset boolean
                if(/^undef$/oi || /^off$/oi || /^false$/oi || /^no$/oi){
                    delete ${$href}{$pname} if(defined(${$href}{$pname}));
                    return 1;
                }
		elsif(defined($ARRS{$pname})){
			push @{${$href}{$pname}}, split;
		}
		else{
			${$href}{$pname} = $_;
                        if(/\~/ || /\$/){
                            ${${$href}{'PATHOPTS'}}{$pname} = 1;
                        }
		}
		return 1;
	}

	return 0;
}

sub load_regex_section{
    my($self,$line,$file,$fh,$type,$match,$count) = @_;
    my($start,$end,$exp,$skip);

    # set start to expression matching <$type=($exp)>
    $start = sprintf "^<%s\\s\*=\\s\*\(\\S\+\)\\s\*>\\s\*", $type;

    # return 0 if this is not a BEGIN section <$type=$exp>
    return $count if(!(($exp) = ($line =~ /$start/i)));

    # set end to expression matching </$type>
    $end = sprintf "^<\\\/%s\\s\*>\\s\*", $type;

    # check if regex matches for this expression
    # (If it doesn't match, set skip so syntax matching will grok
    # lines without setting hash values.)
    $exp =~ s/([^\w\s-])/\\$1/g;
    $exp =~ s/\\\*/.\*/g;
    $exp =~ s/\\\?/./g;
    if(!($match =~ /$exp/)){
        $skip = 1;
    }

    #
    # Grok all lines in this sub-section
    #
    while(<$fh>){
        $count++;
        last if(/$end/i);
        my $line = $_;
        chomp $line;
        die "Syntax error $file:$.:\"$line\"" if(/^</);
        next if $self->load_line($line,$self,$skip);
        # Unknown format
        die "Syntax error $file:$.:\"$line\"";
    }
    return $count;
}

sub load_subhash{
    my($self,$line,$file,$fh,$count) = @_;
    my($type,$end,$name,%subhash);

    if(!(($type,$name) = /^<\s*(\S+)\s*=\s*(\S+)\s*>\s*$/i)){
        return $count;
    }
    $name =~ tr/a-z/A-Z/;
    $type =~ tr/a-z/A-Z/;


    # Keep track of non scalar types to aid in retrieval
    $ARRS{$type."LIST"} = 1;
    $HASHOPTS{$type} = 1;

    # set end to expression matching </$type>
    $end = sprintf "^<\\\/%s\\s\*>\\s\*", $type;

    #
    # Grok all lines in this sub-section
    #
    while(<$fh>){
        $count++;
        last if(/$end/i);
        die "Syntax error $file:$.:\"$_\"" if(/^</);
        next if $self->load_line($_,\%subhash);
        # Unknown format
        die "Syntax error $file:$.:\"$_\"";
    }
    if(exists($self->{$type."-".$name})){
        foreach(keys %subhash){
            ${$self->{$type."-".$name}}{$_} = $subhash{$_};
        }
    }
    else{
        # Set info needed for value retrieval
        # Make a 'list' to enumerate all sub-hashes of this type
        push @{$self->{$type.'LIST'}}, $name;
        %{$self->{$type."-".$name}} = %subhash;
    }
    return $count;
}

# sub load_subfile($$);

sub load_subfile{
	my($self,$line,$count) = @_;
	my($newfile);

	if(!(($newfile) = ($line =~ /^<\s*include\s*=\s*(\S+)\s*>\s*/i))){
		return $count;
	}

	return $self->load_file($self->resolve_path($newfile),$count);
}

sub load_file{
	my($self,$file,$count) = @_;
	my($sysname,$hostname) = POSIX::uname();

	my($pname,$pval,$key,$outcount);
	local(*PFILE);
	open(PFILE, "<".$file) || die "Unable to open $file";
	while(<PFILE>){
		my $line = $_;
		$count++;

		#
		# include files
		#
		$outcount = $self->load_subfile($_,$count);
                if($outcount > $count){
                    $count = $outcount;
                    next;
                }

		#
		# regex matches
		#

		# HOSTNAME
		$outcount = $self->load_regex_section($_,$file,\*PFILE,"HOST",
                        $hostname,$count);
                if($outcount > $count){
                    $count = $outcount;
                    next;
                }
		# OS
		$outcount = $self->load_regex_section($_,$file,\*PFILE,"OS",
                        $sysname,$count);
                if($outcount > $count){
                    $count = $outcount;
                    next;
                }

		# sub-hash's
		$outcount = $self->load_subhash($_,$file,\*PFILE,$count);
                if($outcount > $count){
                    $count = $outcount;
                    next;
                }

		# global options
		next if $self->load_line($_,$self);

		die "Syntax error $file:$count:\"$line\"";
	}

	$count;
}

sub init {
    my($self,%args) = @_;
    my($confdir,$nodename);
    my($name,$file,$key);
    my($sysname,$hostname) = POSIX::uname();

    ARG:
    foreach (keys %args){
        $name = $_;
        $name =~ tr/a-z/A-Z/;
        if($name ne $_){
            $args{$name} = $args{$_};
            delete $args{$_};
        }
        /^confdir$/oi	and $confdir = $args{$name}, next ARG;
        /^node$/oi	and $nodename = $args{$name}, next ARG;
    }

    if(!defined($nodename)){
        ($nodename) = ($hostname =~ /^[^-]*-(\w*)/o) and
            $nodename =~ tr/a-z/A-Z/;
        $self->{'NODE'} = $nodename if(defined($nodename));
    }

    #
    # Global conf file
    #
    if(defined($ENV{$perfSONAR_PS::Config::OWP::Conf::GLOBALCONFENV})){
        $file = $self->resolve_path($ENV{$perfSONAR_PS::Config::OWP::Conf::GLOBALCONFENV});
    }elsif(defined($confdir)){
        $file = $self->resolve_path($confdir.'/'.
            $perfSONAR_PS::Config::OWP::Conf::GLOBALCONFNAME);
    }
    else{
        $file = $self->resolve_path(
            $DEFS{CONFDIR}.'/'.$perfSONAR_PS::Config::OWP::Conf::GLOBALCONFNAME);
    }
    if(-e $file){
        $self->{'GLOBALCONF'} = $file;
        $self->load_file($self->{'GLOBALCONF'},0);
    }else{
        die "Unable to open Global conf:$file";
    }

    undef $file;

    if(defined($ENV{$perfSONAR_PS::Config::OWP::Conf::DEVCONFENV})){
        $file = $self->resolve_path($ENV{$perfSONAR_PS::Config::OWP::Conf::DEVCONFENV});
    }

    if(defined($file) and -e $file){
        $self->{'DEVNODECONF'} = $file;
        $self->load_file($self->{'DEVNODECONF'},0);
    }

    #
    # args passed in as initializers over-ride everything else.
    #
    foreach $key (keys %args){
        $self->{$key} = $args{$key};
    }

    #
    # hard coded	(this modules fallbacks)
    #
    foreach $key (keys(%DEFS)){
        $self->{$key} = $DEFS{$key} if(!defined($self->{$key}));
    }

    return $self;
}

sub get_ref {
    my($self,%args) = @_;
    my($type,$attr,$fullattr,$hopt,$name,@subhash,$ref) =
        (undef,undef,undef,undef,undef,undef,undef);

    ARG:
    foreach (keys %args){
        /^attr$/oi	and $attr = $args{$_}, next ARG;
        /^type$/oi	and $type = $args{$_}, next ARG;
        foreach $hopt (keys %HASHOPTS){
            if(/^$hopt$/i){
                $name = $args{$_};
                $name =~ tr/a-z/A-Z/;
                if(defined($self->{$hopt."-".$name})){
                    push @subhash, $self->{$hopt."-".$name};
                }
                next ARG;
            }
        }
        die "Unknown named parameter $_ passed into get_ref";
    }

    return undef if(!defined $attr );
    $attr =~ tr/a-z/A-Z/;

    if(defined $type ){
        $fullattr = $type . $attr;
        $fullattr =~ tr/a-z/A-Z/;
    }

    # Try sub-hashes
    my $dopath = 0;
    foreach (@subhash){
        if((defined $fullattr) && (defined ${$_}{$fullattr})){
            $ref = ${$_}{$fullattr};
            $dopath = 1 if(defined ${$_}{'PATHOPTS'}  &&
                defined ${${$_}{'PATHOPTS'}}{$fullattr} );
        }
        elsif(defined ${$_}{$attr} ){
            $ref = ${$_}{$attr};
            $dopath = 1 if(defined ${$_}{'PATHOPTS'}  &&
                defined ${${$_}{'PATHOPTS'}}{$attr} );
        }
    }

    # If no value found in sub-hash, try global level
    if(!defined $ref ){
        if((defined $fullattr) && (defined $self->{$fullattr})){
            $ref = $self->{$fullattr};
            $dopath = 1 if(defined($self->{'PATHOPTS'}) &&
                defined(${$self->{'PATHOPTS'}}{$fullattr}));
        }
        elsif(defined $self->{$attr} ){
            $ref = $self->{$attr};
            $dopath = 1 if(defined $self->{'PATHOPTS'}  &&
                defined ${$self->{'PATHOPTS'}}{$attr} );
        }
    }

    if($ref && $dopath){
        return $self->resolve_path($ref);
    }

    return $ref;
}

#
# This is a convienence routine that returns no value
# if the value isn't retrievable.
#
sub get_val {
    my($self,%args)	= @_;
    my($ref);

    for ($ref = $self->get_ref(%args)){
        return if(!defined($_));
        /SCALAR/	and return $$ref;
        /HASH/		and return %$ref;
        /ARRAY/		and return @$ref;
        die "Invalid value in hash!?" if(ref($ref));
        # return actual value
        return $ref;
    }

    # not reached
    return undef;
}

#
# This is a convienence routine that dies with
# an error message if the value isn't retrievable.
#
sub must_get_val {
    my($self,%args)	= @_;
    my($ref);

    for ($ref = $self->get_ref(%args)){
        # undef:break out and report error.
        last if(!defined($_));
        /SCALAR/	and return $$ref;
        /HASH/		and return %$ref;
        /ARRAY/		and return @$ref;
        die "Invalid value in hash!?" if(ref($ref));
        # return actual value.
        return $ref;
    }

    my($emsg) = "";
    $emsg.="$_=>$args{$_}, " for (keys %args);
    my($dummy,$fname,$line) = caller;
    die "Conf::must_get_val($emsg) undefined, called from $fname\:$line\n";
}

#
# This is a convienence routine that returns values from a LIST
# if and only if the sub-hash has a particular value set.
#
sub get_sublist{
    my($self,%args) = @_;
    my($ref);
    my($list,$attr,$value);

    ARG:
    foreach (keys %args){
        /^list$/oi	and $list = $args{$_}, next ARG;
        /^attr$/oi	and $attr = $args{$_}, next ARG;
        /^value$/oi	and $value = $args{$_}, next ARG;
        die "Unknown named parameter $_ passed into get_ref";
    }

    return undef if(!defined($list));

    $list =~ tr/a-z/A-Z/;
    my @list = $self->get_val(ATTR=>$list.'LIST');

    # return full list if no qualifier attached
    return @list if(!defined($attr));

    # determine qualified sublist using attr/value
    my @sublist;
    $attr =~ tr/a-z/A-Z/;

    foreach (@list){
        my $subval = $self->get_val($list=>$_,ATTR=>$attr);
        if(defined($subval) && (!defined($value) || ($subval eq $value))){
            push @sublist,$_;
        }
    }

    return if(!scalar(@sublist));
    return @sublist;
}

#
# This is a convienence routine that dies with
# an error message if the value isn't retrievable.
#
sub must_get_sublist{
	my($self,%args)	= @_;
	my($ref);

        my @sublist = $self->get_sublist(%args);

        return @sublist if(scalar @sublist);

	my($emsg) = "";
	$emsg.="$_=>$args{$_}, " for (keys %args);
	my($dummy,$fname,$line) = caller;
	die "Conf::must_get_sublist($emsg) undefined, called from $fname\:$line\n";
}

#
# This is a convienence routine that returns values from a LIST
# if and only if the sub-hash has a particular value set.
#
sub get_list{
    my($self,%args) = @_;
    my($ref);
    my($list,$attr,$value);

    my(@mustargnames) = qw(LIST);
    my(@argnames) = (@mustargnames, qw(ATTR VALUE FILTER));
    %args = owpverify_args(\@argnames,\@mustargnames,%args);
    if( !scalar %args){
        return undef;
    }

    $list = $args{'LIST'};
    $attr = $args{'ATTR'};
    $value = $args{'VALUE'};
    my $filterref = $args{'FILTER'};
    my(%filter);

    if(defined($filterref)){
        %filter = %$filterref;
    }

    if(defined($attr)){
        $filter{$attr} = $value;
    }

    foreach (keys %filter){
        $attr = $_;
        $attr =~ tr/a-z/A-Z/;

        if($attr ne $_){
            $filter{$attr} = $filter{$_};
            delete $filter{$_};
        }
    }

    my @list = $self->get_val(ATTR=>$list.'LIST');

    # return full list if no qualifier attached
    return @list if(!scalar %filter);

    # determine qualified sublist using attr/value pairs
    my @sublist;
    my $l;

    LIST:
    foreach $l (@list){
        ATTR:
        foreach $attr (keys %filter){
            my $subval = $self->get_val($list=>$l,ATTR=>$attr);
            my $reqval = $filter{$attr};

            if(defined($subval) && (!defined($reqval) || ($subval eq $reqval))){
                next ATTR;
            }

            next LIST;
        }
        push @sublist,$l;
    }

    return if(!scalar(@sublist));
    return @sublist;
}

#
# This is a convienence routine that dies with
# an error message if the value isn't retrievable.
#
sub must_get_list{
	my($self,%args)	= @_;
	my($ref);

        my @sublist = $self->get_list(%args);

        return @sublist if(scalar @sublist);

	my($emsg) = "";
	$emsg.="$_=>$args{$_}, " for (keys %args);
	my($dummy,$fname,$line) = caller;
	die "Conf::must_get_sublist($emsg) undefined, called from $fname\:$line\n";
}


sub dump_hash{
	my($self,$href,$pre)	=@_;
	my($key);
	my($rtnval) = "";

	KEY:
	foreach $key (sort keys %$href){
		my($val);
		$val = "";
		for (ref $href->{$key}){
			/^$/	and $rtnval.= $pre.$key."=$href->{$key}\n",
					next KEY;
			/ARRAY/	and $rtnval.= $pre.$key."=\[".
					join(',',@{$href->{$key}})."\]\n",
					next KEY;
			/HASH/ and $rtnval.=$pre.$key."[\n".
				$self->dump_hash($href->{$key},"$pre\t").
					$pre."]\n",
					next KEY;
			die "Invalid hash value!";
		}
	}

	return $rtnval;
}


sub dump{
	my($self)	= @_;

	return $self->dump_hash($self,"");
}

1;
