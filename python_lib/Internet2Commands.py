#!/usr/bin/python
#
# File to hold the command objects for the menu choices
# Author: Dan Bracey 6/5/08
# Revision History:
# 6/5/08 -- 1.000 -- debracey -- Initial Creation

import Internet2Lib     # Library Functions
import Internet2Consts  # Constants
import os               # OS (to call the binaries)
import time             # Timezone information

### ALL functions take a userData object as a parameter, and return the object ###
### Basically, this thing should just call the underlying py scripts that do 99% of the work ###
### The motivation here is that we want to make the end script accessible to the end user -- without the wrapper tool ###

### The -ns option is used to supress the saving operation that all of the tools try to do by default 

# Get site info
def getSiteInfo(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "create-siteinfo.py")
# End getSiteInfo

# Set built-in passwords
def setBuiltInPasswords(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "set_default_passwords")
# End getSiteInfo

# BWCTL
def bwctl(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "create-bwctl.py")
# End bwctl

# BWCTL
def bwctl(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "create-bwctl.py")
# End bwctl

# NDT
def ndt(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "create-ndt.py")
# End NDT

# NPAD
def npad(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "create-npad.py")    
# End NPAD

# NTP
def ntp(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "create-ntp.py")
# End NTP

# OWAMP
def owamp(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "create-owamp.py")
# End owamp

# Static IP
def networking(duringBootup):
    # Run the actual command (no marker file, optional)
    os.system("/usr/sbin/system-config-network-tui")
# End staticIP

# Security tools
def securityTools(duringBootup):
    # Run the actual command (no marker file, optional)
    os.system(Internet2Consts.BIN_DIR + "create-tools.py") 
# End securityTools

# Drive customization
def setupDrives(duringBootup):
    # Run the actual command (no marker file, optional)
    os.system(Internet2Consts.BIN_DIR + "create_backing_store")
# End setupDrives

# Configure running services
def configureRunningServices(duringBootup):
    if (duringBootup):
        os.system(Internet2Consts.BIN_DIR + "create-services.py during_boot") 
    else:
        os.system(Internet2Consts.BIN_DIR + "create-services.py") 
# End setupDrives


def changeTimezone(duringBootup):
    os.system("/usr/bin/system-config-date")
# end changeTimezone

# External access point customization
def externalAccesspoint(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "lookup_external_addr.pl")
# End externalAccesspoint

# Add/Delete Users and Change their passwords
def manageUsers(duringBootup):
    os.system(Internet2Consts.BIN_DIR + "manage_users")
# End manageUsers

# Apache start/stop
def startstop_apache(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.APACHE_INIT_SCRIPT + " " + startstop)


# SSH start/stop
def startstop_ssh(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.SSH_INIT_SCRIPT + " " + startstop)

# BWCTL start/stop
def startstop_bwctl(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.BWCTL_INIT_SCRIPT + " " + startstop)
# End BWCTL start/stop

# OWAMP start/stop
def startstop_owamp(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.OWAMP_INIT_SCRIPT + " " + startstop)
# End OWAMP start/stop

# NDT start/stop
def startstop_ndt(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.NDT_INIT_SCRIPT + " " + startstop)
# End NDT start/stop

# NPAD start/stop
def startstop_npad(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.NPAD_INIT_SCRIPT + " " + startstop)
# End NPAD start/stop

# PingER start/stop
def startstop_pinger(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.PINGER_INIT_SCRIPT + " " + startstop)
# End PingER start/stop

# SNMP MA start/stop
def startstop_snmpma(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    return os.system(Internet2Consts.SNMP_MA_INIT_SCRIPT + " " + startstop)
# End SNMP MA start/stop

# PSB start/stop
def startstop_psb(startstop):
    if (startstop != "start" and startstop != "stop" and startstop != "restart"):
        return -1

    os.system(Internet2Consts.PSB_MA_INIT_SCRIPT + " " + startstop)
    os.system(Internet2Consts.PSB_MASTER_INIT_SCRIPT + " " + startstop)
    os.system(Internet2Consts.PSB_COLLECTOR_INIT_SCRIPT + " " + startstop)
# End PSB start/stop


