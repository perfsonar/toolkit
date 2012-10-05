package perfSONAR_PS::NPToolkit::BackingStore::Utils;

use strict;
use warnings;

our $VERSION = 3.2;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);

=head1 NAME

perfSONAR_PS::NPToolkit::BackingStore::Utils

=head1 DESCRIPTION

TBD

=head1 API

=cut

use File::Path qw(mkpath);
use Config::General qw(SaveConfigString ParseConfig);

use base 'Exporter';

our @EXPORT_OK = qw( mount_data_store load_live_device unload_live_device );

our $store_info_location = "/var/run/toolkit/backing_store.info";
our $store_location      = "/mnt/store";
our $new_store_location  = "/mnt/store.new";
our $live_dir            = "/mnt/live";
our $squashfs_dir        = "/mnt/squashfs";
our $toolkit_dir         = "/mnt/toolkit";

=head2 mount_data_store({ })

TBD

=cut
sub mount_data_store {
    my $parameters = validate( @_, { });

    my $error;

    if (-e $store_info_location) {
        my ($status, $res) = load_store_info({ file => $store_info_location });
        if ($status == 0) {
            # we should now have the version, store location and device
            my $store_path    = $res->{path};
            my $store_version = $res->{version};
            my $store_device  = $res->{device};

            # validate the mount point and return the values (i.e. check that
            # it is actually mounted, etc).
            my $mounted_device = get_mounted_device({ directory => $store_path });

            unless ($mounted_device and $store_device eq $mounted_device) {
                return (-1, "Inconsistent device specified: $store_device != $mounted_device");
            }

            return (0, { directory => $store_path, device => $store_device, version => $store_version });
        }
    }

    # Create the default store location if it doesn't exist
    unless (-d $store_location) {
        mkpath($store_location, { error => \$error });
        if (($error) && (scalar(@$error) > 0)) {
            return (-1, "Couldn't make data store directory");
        }
    }

    # If the backing store appears to be mounted, use that and attempt to
    # reload the version info and figure out the mounted device
    if (-e $store_location."/NPTools") {
        my $version = "";

        # Re-read the version info
        if (-e $store_location."/NPTools/version") {
            if (open(VERSION, $store_location."/NPTools/version")) {
                local( $/ );
                $version = <VERSION>;
                close(VERSION);

                chomp($version);
            }
        }

        # XXX: find the device
        my $device = get_mounted_device({ directory => $store_location });

        unless ($device) {
            return (-1, "Contents of $store_location are ambiguous");
        }

        my ($status, $res) = save_store_info({ file => $store_info_location, store_location => $store_location, device => $device, version => $version });
        if ($status != 0) {
            # complain, but don't error out since the store file is actually
            # mounted.
        }

        return (0, { directory => $store_location, device => $device, version => $version });
    }

    my $mounted_dev;

    if (open(BLKID, "-|", "blkid -o device -t TYPE='ext3'")) {
        while(my $dev = <BLKID>) {
            chomp($dev);
            `mount -t ext3 $dev $store_location &> /dev/null`;
            if ($?) {
                # XXX: disply an error
                next;
            }

            if ( -e "$store_location/NPTools" ) {
                $mounted_dev=$dev;
                last;
            }
            else {
                `umount $store_location &> /dev/null`;
            }
        }
    }

    unless ($mounted_dev) {
    # blkid (in the case of Brian Tierney's machine) was not outputing
    # /dev/sda even though /dev/sda was available, and ext3. To work around
    # this, we manually grot through /proc/partitions looking for ext3
    # devices that blkid didn't display.
        if (open(PARTITIONS, "<", "/proc/partitions")) {
            while(<PARTITIONS>) {
                my ($major, $minor, $blocks, $name) = split;

                next unless ($name);

                my $dev = "/dev/$name";

                unless (-e $dev) {
                    # XXX: display an error or something
                    next;
                }
                chomp($dev);
                `mount -t ext3 $dev $store_location &> /dev/null`;
                if ($?) {
                    # XXX: disply an error
                    next;
                }

                if ( -e "$store_location/NPTools" ) {
                    $mounted_dev=$dev;
                    last;
                }
                else {
                    `umount $store_location &> /dev/null`;
                }
            }
            close(PARTITIONS);
        }
    }

    unless ($mounted_dev) {
        return (-1, "Couldn't find partition with a data store on it");
    }

    my $version;

    if (-e $store_location."/NPTools/version") {
        if (open(VERSION, $store_location."/NPTools/version")) {
            local( $/ );
            $version = <VERSION>;
            close(VERSION);

            chomp($version);
        }
    }

    my ($status, $res) = save_store_info({ file => $store_info_location, store_location => $store_location, device => $mounted_dev, version => $version });
    if ($status != 0) {
        # complain, but don't error out since the store file is actually
        # mounted.
    }

    return (0, { directory => $store_location, device => $mounted_dev, version => $version });
}

sub load_live_device {
    my $parameters = validate( @_, { });

    for my $dir ($live_dir, $squashfs_dir, $toolkit_dir) {
        my $error;

        mkpath($dir, { error => \$error }) unless (-d $dir);
        if (($error) && (scalar(@$error) > 0)) {
            return (-1, "Couldn't make $dir");
        }
    }

    unless ( -f "$live_dir/squashfs.img" or -f "$live_dir/LiveOS/squashfs.img" ) {
        `mount -o ro /dev/live $live_dir &> /dev/null`
    }

    unless ( -f "$live_dir/squashfs.img" or -f "$live_dir/LiveOS/squashfs.img" ) {
        return (-1, "Couldn't find live device");
    }

    unless ( -f "$squashfs_dir/os.img" or -f "$squashfs_dir/LiveOS/ext3fs.img" ) {
        if (-f "$live_dir/squashfs.img") {
            `mount -t squashfs -o loop $live_dir/squashfs.img $squashfs_dir &> /dev/null`;
        }
        else {
            `mount -t squashfs -o loop $live_dir/LiveOS/squashfs.img $squashfs_dir &> /dev/null`;
        }
    }

    unless ( -f "$squashfs_dir/os.img" or -f "$squashfs_dir/LiveOS/ext3fs.img" ) {
        return (-1, "Couldn't load squashfs image");
    }

    unless ( -f "$toolkit_dir/bin/bash" ) {
        if (-f "$squashfs_dir/os.img") {
            `mount -t ext3 -o loop $squashfs_dir/os.img $toolkit_dir &> /dev/null`
        }
        else {
            `mount -t ext3 -o loop $squashfs_dir/LiveOS/ext3fs.img $toolkit_dir &> /dev/null`
        }
    }

    unless ( -f "$toolkit_dir/bin/bash" ) {
        return (-1, "Couldn't load ext3 image");
    }

    return (0, { directory => $toolkit_dir });
}

sub unload_live_device {
    my $parameters = validate( @_, { });

    for my $dir ($live_dir, $squashfs_dir, $toolkit_dir) {
        my $error;

        mkpath($dir, { error => \$error }) unless (-d $dir);
        if (($error) && (scalar(@$error) > 0)) {
            return (-1, "Couldn't make $dir");
        }
    }

    if ( -f "$toolkit_dir/bin/bash" ) {
        `umount $toolkit_dir &> /dev/null`
    }

    if ( -f "$toolkit_dir/bin/bash" ) {
        return (-1, "Couldn't unmount ext3 image");
    }

    if ( -f "$squashfs_dir/os.img" or -f "$squashfs_dir/LiveOS/ext3fs.img" ) {
        `umount $squashfs_dir &> /dev/null`;
    }

    if ( -f "$squashfs_dir/os.img" or -f "$squashfs_dir/LiveOS/ext3fs.img" ) {
        return (-1, "Couldn't unmount squashfs image");
    }

    if ( -f "$live_dir/squashfs.img" or -f "$live_dir/LiveOS/squashfs.img" ) {
        `umount $live_dir &> /dev/null`
    }

    if ( -f "$live_dir/squashfs.img" or -f "$live_dir/LiveOS/squashfs.img" ) {
        return (-1, "Couldn't unmount live device");
    }


    return (0, "");
}

sub make_data_store {
    my $parameters = validate( @_, {
                                    device => 1,
                                    format => 1,
                                    scratch_size => 1
                            });
    my $dev = $parameters->{device};
    my $format = $parameters->{format};
    my $scratch_size = $parameters->{scratch_size};

    unless ($scratch_size) {
        # 1G
        $scratch_size=1_000_000_000;
    }

    if ( $format ) {
        `mkfs.ext3 -F $dev &> /dev/null`;
        if ($?) {
            return (-1, "Couldn't format device: $?");
        }
    }

    my $error;

    mkpath($new_store_location, { error => \$error }) unless (-d $new_store_location);
    if (($error) && (scalar(@$error) > 0)) {
        return (-1, "Couldn't create new store location");
    }

    `mount -t ext3 $dev $new_store_location &> /dev/null`;
    if ($?) {
        return (-1, "Couldn't mount device $dev");
    }

    mkpath($new_store_location."/NPTools", { error => \$error }) unless (-d $new_store_location."/NPTools");
    if (($error) && (scalar(@$error) > 0)) {
        return (-1, "Couldn't create new store location");
    }

    `dd if=/dev/zero of=$new_store_location/NPTools/scratch bs=1 count=1 seek=$scratch_size &> /dev/null`;
    if ($?) {
        return (-1, "Couldn't create new scratch file");
    }

    # should we run save configuration?

    return (0, { directory => $new_store_location });
}

sub load_store_info {
    my $parameters = validate( @_, {
                                    file => 0,
                            });

    my $file = $parameters->{file};

    $file = $store_info_location unless ($file);

    my %config;
    eval {
        %config = ParseConfig(-ConfigFile => $file);
    };
    if ($@) {
        return (-1, "Couldn't parse ".$file);
    }

    my $version = $config{version};
    my $device  = $config{device};
    my $path    = $config{path};

    return (0, { device => $device, version => $version, path => $path });
}

sub save_store_info {
    my $parameters = validate( @_, {
                                    file => 0,
                                    store_location => 1,
                                    device => 1,
                                    version => 1,
                            });

    my $file = $parameters->{file};

    $file = $store_info_location unless ($file);

    my %store_info = (
                        version => $parameters->{version},
                        device => $parameters->{device},
                        path => $parameters->{store_location}
                    );

    my $config_str = SaveConfigString(\%store_info);

    unless (open(CONFIG, ">", $file)) {
        return (-1, "Couldn't open ".$file);
    }

    print CONFIG $config_str;
    close(CONFIG);

    return (0, "");
}

sub get_mounted_device {
    my $parameters = validate( @_, {
                                    directory => 1,
                            });

    my $directory = $parameters->{directory};

    my $device;

    if (open(MOUNTS, "<", "/proc/mounts")) {
        while(<MOUNTS>) {
            chomp;
            my ($curr_dev, $mount_point, $junk) = split;

            if ($mount_point eq $directory) {
                $device = $curr_dev;
            }
        }
        close(MOUNTS);
    }

    return $device;
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2008-2010, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
