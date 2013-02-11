#!/usr/bin/python
#
# This script should be called late in the boot process.  It
# will check to see if any of the AMI tools need to be customized
# and will run the individual tool customization scripts.
# 
# Original Author: Rich Carlson 4/21/06
# Revised (port to python): Dan Bracey
# Revision History:
# 5/29/08 -- 1.000 -- debracey -- Initial port to python, no new functionality added
# 5/29/08 -- 1.001 -- debracey -- Added user object and method to parse input from user
# 5/30/08 -- 1.002 -- debracey -- Added methods to handle menu selections
# 6/5/08  -- 1.100 -- debracey -- Front end user display is complete, all options do the correct thing
# 7/5/08  -- 1.101 -- debracey -- General cleanup/impovements to prep for midterm eval

import os
import sys

bindir = os.path.abspath(os.path.dirname(os.path.realpath(sys.argv[0])))
libdir = os.path.join(bindir, "..", "python_lib")

sys.path.append(libdir)

import os.path             # For file IO
import sys                 # For stdin
import select              # Timeouts/non-blocking IO
import readline            # Improve the usability of raw_input. Let you use those fancy "arrow" keys
import Internet2Lib        # Library functions 
import Internet2Consts     # Constants

# Default timeout for menu options
needReboot      = False

def storeConfigured():
    return os.path.exists("/var/run/toolkit/backing_store.info")

def passwordsConfigured():
    defaultPasswords = { "root": "saFLGt/QKS6yw" }
    for user in defaultPasswords.keys():
        password = lookupShadowPassword(user)
        if password and password == defaultPasswords[user]:
            return False
    return True

# We'll let each tool be a toolkitItem object
# Has basic info (name, executable path, config path, if it required (True/False), if it already configured (True/False), if it should display in whatever color regardless
class toolkitItem:
    def __init__(self, name, executablePath, configuredFunction=None, required=False, needsReboot=False):
        self.name               = name
        self.executablePath     = executablePath
        self.configuredFunction = configuredFunction
        self.required           = required
        self.needsReboot        = needsReboot

    # Determines if a tool is configured
    # @return true if configured, false otherwise
    def isConfigured(self):
        if self.configuredFunction:
            return self.configuredFunction()
        else:
            return None

    # Determines the color for the given tool
    # Color is determined by two factors
    # 1: If it is configured (automatic green)
    # 2: If it is required (red if not configured & required, otherwise magenta)
    # @return A string with the proper coloring
    def showColor(self):
        # Green if configure
        if self.isConfigured() == True:
            return Internet2Consts.GREEN + self.name + Internet2Consts.NORMAL
        # Magenta if not required
        elif self.required and self.isConfigured() == False:
            return Internet2Consts.MAGENTA + self.name + Internet2Consts.NORMAL
        # Default case, not configured
        else:
            return self.name
    # End showColor
# End toolkitItem

# Initializes the toolkit items
# @return A list of toolkitItem objects with the proper values
def initialize():

    known_items = [
                    {
                         "description": "Configure drive to hold data/customizations",
                         "command": "/opt/perfsonar_ps/toolkit/scripts/create_backing_store",
                         "isConfiguredFunction": storeConfigured,
                         "required": True,
                         "requiresReboot": True,
                    },
                    {
                         "description": "Set built-in account passwords",
                         "command": "/opt/perfsonar_ps/toolkit/scripts/set_default_passwords",
                         "isConfiguredFunction": passwordsConfigured,
                         "required": True,
                         "requiresReboot": False,
                    },
                    {
                         "description": "Configure Networking",
                         "command": "/usr/sbin/system-config-network-tui",
                         "isConfiguredFunction": None,
                         "required": False,
                         "requiresReboot": True,
                    },
                    {
                         "description": "Change Timezone",
                         "command": "/usr/bin/system-config-date",
                         "isConfiguredFunction": None,
                         "required": False,
                         "requiresReboot": True,
                    },
                    {
                         "description": "Manage Users",
                         "command": "/opt/perfsonar_ps/toolkit/scripts/manage_users",
                         "isConfiguredFunction": None,
                         "required": False,
                         "requiresReboot": False,
                    },
#                    {
#                         "description": "Backup data/configurations",
#                         "command": "/opt/perfsonar_ps/toolkit/scripts/",
#                         "isConfiguredFunction": None,
#                         "required": False,
#                         "requiresReboot": False,
#                    },
#                    {
#                         "description": "Restore data/configurations",
#                         "command": "/opt/perfsonar_ps/toolkit/scripts/",
#                         "isConfiguredFunction": None,
#                         "required": False,
#                         "requiresReboot": True,
#                    },
                 ]
    items = []

    for item in known_items:
        # Skip the item if it's associated command isn't available.
        if (not os.path.exists(item["command"])):
            continue

        item = toolkitItem(item["description"], item["command"], item["isConfiguredFunction"], item["required"], item["requiresReboot"])

        items.append(item)
  
    return items
# End initalize

# Displays the menu
# MUST be called after itialize (it accesses the NPTools list)
# ** Does NOT modify the NPTools list
def displayMenu():
    print "\nInternet2 Network Performance Toolkit customization script"
    print "Options in " + Internet2Consts.MAGENTA + "MAGENTA" + Internet2Consts.NORMAL + " have yet to be configured"
    print "Options in " + Internet2Consts.GREEN + "GREEN" + Internet2Consts.NORMAL + " have already been configured"
    print ""
    
    for i, tool in enumerate(NPTools):
        print str(i+1) + ". " + tool.showColor() + Internet2Consts.NORMAL
        
    print "0. exit\n"
    
    return
# End displayMenu

def lookupShadowPassword(user):
    shadow = open('/etc/shadow', 'r')
    for line in shadow:
        fields = line.split(":")
        if fields[0] == user:
            return fields[1]
    return None

# Processes the menu choice (does a do-while until the choice is 0 or timeout)
def mainLoop():
    global needReboot

    # we only want to timeout if they are booting up, so if they manually start
    # it, ignore the timeout
    done = False
    
    while not done:
        # we only let them exit when they've configured the required services

        missingRequired = False
        for i, tool in enumerate(NPTools):
            if tool.required and not tool.isConfigured():
                missingRequired = True

        displayMenu()
        print "Make a selection: ",
        sys.stdout.flush() # Force display 
        
        # Process the user's input
        try:
            choice = int(sys.stdin.readline().strip())
        except ValueError, e:
            choice = -1 # Not valid
        print " "
        
        # Negative numbers are invalid -- as are choices > the length of the choice list plus 2 (Exit and Reconfig are not in the thing)
        if choice < 0 or choice > len(NPTools):
            print Internet2Consts.YELLOW + "Invalid selection" + Internet2Consts.NORMAL
            continue
        
        # Exit if choice is 0
        elif choice == 0:
            missingRequired = False
            for i, tool in enumerate(NPTools):
                if tool.required and not tool.isConfigured():
                    missingRequired = True
                    break

            if missingRequired == False:
                done = True
            else:
                print Internet2Consts.YELLOW + "There are still unconfigured options that need to be configured" + Internet2Consts.NORMAL

                ans = raw_input("Are you sure you want to exit? Doing so might lead to unexpected results [n] ").strip().upper();
                if not ans:
                    ans = "N"

                if ans[0] == "Y":
                    done = True
        else:
	    if NPTools[choice-1].isConfigured():
                print Internet2Consts.YELLOW + "This option has already been configured." + Internet2Consts.NORMAL

                ans = raw_input("Would you like to reconfigure? [y] ").strip().upper();
                if not ans:
                    ans = "Y"

                if ans[0] == "N":
                    continue
	        
	    os.system(NPTools[choice-1].executablePath)
            if NPTools[choice-1].needsReboot == True:
                needReboot = True
    return
# End mainLoop

### MAIN ###
# Must be root
if not Internet2Lib.isRoot():
    print Internet2Consts.YELLOW + "You must run the Internet2 pS-Performance Toolkit configuration script as root." + Internet2Consts.NORMAL
    sys.exit(1)


# Initialize the list of NPTools
# Will exit if all tools are configured
NPTools = initialize()

# Display the menu & process the choice
mainLoop()

if needReboot:
    print "The changes you have made require a reboot. Would you like to reboot? [y] ",
    sys.stdout.flush() # Force display 
        
    # Get the user's input
    try:
        choice = sys.stdin.readline().strip()
    except ValueError, e:
        choice = -1 # Not valid
    print " "

    if choice == "" or choice[:1] == "y" or choice[:1] == "Y":
        os.system("/sbin/reboot");
    else:
        print "You have chosen not to reboot. You should reboot as soon as possible to ensure that everything works as expected"
### END MAIN ###

