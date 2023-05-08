# Function lib for Internet2-NPT script
# Author: Dan Bracey 5/30/08
# Revision History:
# 5/30/08 -- 1.000 -- debracey -- Initial Creation, user data input processing moved here
# 6/5/08  -- 1.010 -- debracey -- Added support for external shell calls (runCommand)
# 7/10/08 -- 1.020 -- debracey -- Force mount during drive listing, can't get stats without mount

import os              # For file IO
import shutil          # For copying
import sys             # For stdin
import socket          # For IP info
import subprocess      # For shell commands
import Internet2Consts # I2 constants
import datetime        # For getting the current time
import getpass         # For password I/O

# Runs the given command - returns the results as a list (delimited by newlines)
# @param command The command to run
# @return The lst of results, or None if empty
def runCommand(command):
    result = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE).communicate()[0]

    if not result:
        return None
    else:
        return result.split("\n")[:-1] # Has an empty line on the end, trash it
# End runCommand

# Actually runs the saveconfig thing
# @param mntPoint The mount point of the device to save to
# @param saveLogs Set to 0 if you dont want to save logs - 1 otherwise
# *** You MUST mount the HDD first -- we suggest using Internet2Lib.forceMount(dev, mntPoint)
# @return True on success, false otherwise
def saveConfig():
    # Now run our special saveconfig script!
    print("running "+Internet2Consts.SAVECONFIG + " >/dev/null 2>&1")
    retVal = os.system(Internet2Consts.SAVECONFIG + " >/dev/null 2>&1")

    # Now return true/false depending on the retVal
    if retVal == 0:
        return True
    else:
        return False
# End saveConfig

# Forces the drive to mount
# @param dev The device to mount
# @param mnt The mount point
def forceMount(dev, mnt):
    # Mount the HDD (try to conceal it in black text
    print(Internet2Consts.BLACK)
    print(os.system("cd / >/dev/null 2>&1; mount " + dev + " " + mnt + " >/dev/null 2>&1; cd - >/dev/null 2>&1"))
    print(Internet2Consts.NORMAL)
    return
# End forceMount

# Forces the drive to mount
# @param mnt The mount point
def unmount(mnt):
    # unmount the HDD (try to conceal it in black text
    print(Internet2Consts.BLACK)
    print(os.system("cd / >/dev/null 2>&1; umount " + mnt + " >/dev/null 2>&1; cd - >/dev/null 2>&1"))
    print(Internet2Consts.NORMAL)
    return
# End unmount

# We'll save the site's information in a userData object
# Has basic info (full name, site name, location, speed, contact email [user and domain], Trouble report subject)
class userData:
    def __init__(self, fullName, siteName, location, linkSpeed, email, subject, projects):
        self.fullName  = fullName
        self.siteName  = siteName
        self.location  = location
        
        if linkSpeed == 1:
            linkSpeed = "100 Mbps (Fast Ethernet)"
        elif linkSpeed == 2:
            linkSpeed = "1000 Mbps (Gigabit Ethernet)"
        elif linkSpeed == 3:
            linkSpeed = "10 Gbps (10 Gig Ethernet)"
        
        self.linkSpeed = linkSpeed
        
        email = email.split("@")
        self.emailUser     = email[0]
        self.emailHost     = email[1]
        
        self.subject       = subject

        self.projects      = projects
        return
    
    # Writes the userData object a file
    # @param  file The file to write to
    def writeUserInfo(self,file):    
        try:
            fileHandle      = open(file, "w")
            fileHandle, res = writeLines(fileHandle, self.fileFormat())
            fileHandle.close()
            if not res:
                raise IOError
        except IOError:
            print(Internet2Consts.YELLOW + "Failed to write to file: " + file + " -- site info not saved. (Check file/folder permissions)" + Internet2Consts.NORMAL)
        
        return
    # End writeUserInfo
    
    # Gets the speed code (1 - 3) based on the site's speed
    def getSpeedCode(self):
        try:
            # Maybe it's already an int?
            speedCode = int(self.linkSpeed)
            return speedCode
        except ValueError:
            pass
        
        if self.linkSpeed.strip() == "100 Mbps (Fast Ethernet)":
            return 1
        elif self.linkSpeed.strip() == "10 Gbps (10 Gig Ethernet)":
            return 3
        else:
            # 2 is the default case
            return 2
    # End getSpeedCode
    
    # Formats the user data object into a file string
    def fileFormat(self):
        objArray = []
        
        objArray.append("full_name=" + self.fullName)
        objArray.append("site_name=" + self.siteName)
        objArray.append("site_location="  + self.location)
        objArray.append("link_spd="  + self.linkSpeed)
        objArray.append("email_usr=" + self.emailUser)
        objArray.append("email_hst=" + self.emailHost)
        objArray.append("email_sub=" + self.subject)
        for project in self.projects:
            objArray.append("site_project=" + project)
    
        return objArray
    # End fileFormat

# end userData

# Reads the file into a userData object
# If the file is malformed - this method will call getUserInfo() (unless told not to) and return that, otherwise returns what was in the file
# @param file The file to read from (absolute path)
# @return A userData object representing the file data (or user input, if malformed file) (If regenerate is turned off, it returns null)
def parseUserInfo(file):
    
    # If the file does not exist, make them make a new
    if not os.path.isfile(file):
        return None
    # Done checking to see if the file exists
        
    try:
        fileHandle = open(file, "r")
        fileHandle, fileLines = readFile(fileHandle)
        
        if fileLines == None:
            raise IOError
        
        full_name  = ""
        site_name  = ""
        location   = ""
        link_spd   = ""
        email_usr  = ""
        email_hst  = ""
        email_sub  = ""
        projects   = []
        
        for line in fileLines:
            line = line.strip()
            
            if line[0:10] == "full_name=":
                full_name = line[10:]
                continue
            elif line[0:10] == "site_name=":
                site_name = line[10:]
                continue
            elif line[0:14] == "site_location=":
                location = line[14:]
                continue
            elif line[0:13] == "site_project=":
                projects_str = line[13:]
                projects.append(projects_str.strip())
                continue
            elif line[0:9] == "link_spd=":
                link_spd = line[9:]
                continue
            elif line[0:10] == "email_usr=":
                email_usr = line[10:]
                continue
            elif line[0:10] == "email_hst=":
                email_hst  = line[10:]
                continue
            elif line[0:10] == "email_sub=":
                email_sub  = line[10:]
                continue
            else:
                continue
        # End loop parsing info file
        
        # Check for problems
        if not full_name or not site_name or not location or not link_spd or not email_usr or not email_hst or not email_sub:
            raise IOError
        else:
            user = userData(full_name, site_name, location, link_spd, email_usr+"@"+email_hst, email_sub, projects)
        
        fileHandle.close()
    except IOError:
        # Not readable
        return None
        # End not readable
        
    return user
# End parseUserInfo

# Gets the hostname
# @return the computer's hostname (or NPToolkit in error)
def getHostname():
    host = str(socket.gethostname())
    
    if not host:
        host = "Unknown"
    
    return host
# End getHostname

# Checks to see if the script is running as root
# @return True if root - false otherwise
def isRoot():
    if os.getuid() == 0:
        return True
    
    return False
# End isRoot

# Removes the given file
# @param file the file to remove
# @return True if removed successfully, false otherwise
def removeFile(file):
    try:
        os.remove(file)
        return True
    except OSError:
        return False
    
    return False
# End removeFile

# Saves userData to a given template file
# @param user The userData object to save to the template file
# @param template The template file to use (see notes about standard Internet2 templating)
# @param saveLocation The location to save to
def parseTemplate(user, template, saveLocation):
    # If no user - return false
    if not user:
        return 
    
    # Open both files
    try:
        template                = open(template)
        template, templateLines = readFile(template)
        
        saveLocation            = open(saveLocation, "w")
        
        if not templateLines:
            raise IOError
        
        # Do the replacing
        for i, line in enumerate(templateLines):
            line = line.replace("%%youremail%%", user.emailUser + "@" + user.emailHost)
            line = line.replace("%%yourname%%", user.fullName)
            line = line.replace("%%yoursubject%%", user.subject)
            line = line.replace("%%yourdomain%%", user.emailHost)
            line = line.replace("%%youruser%%", user.emailUser)
            line = line.replace("%%site%%", user.siteName)
            line = line.replace("%%location%%", user.location)
            line = line.replace("%%yourspeed%%", user.linkSpeed)
            line = line.replace("%%hostname%%", getHostname())
            
            templateLines[i] = line
        
        # Write out the file
        writeLines(saveLocation, templateLines)
        
        template.close()
        saveLocation.close()
    except IOError:
        return False
    
    return True
# End parseTemplate

# Resynchronizes the tools on the toolkit after updating the user data
# @param user The new user data object --- DEPRECATED: The user object is now read by the resync script
# @return True if success, False otherwise (only returns false if you are not running as root)
def resync(user):
    # Call the resync script
    res = os.system(Internet2Consts.BIN_DIR+"resync.py")
    if str(res).strip() == "0":
        return True
    else:
        return False
# End resync

# Gets the current timestamp -- returns it as a string
def getTimestamp():
    return str(datetime.datetime.now())
# End getTimestamp

# Searches the set of lines for a given string
# @param needle the string to find in the file
# @param haystack the file (a list of lines)
# @param deep If set to true, we will search each line for the needle (as opposed to just the wholistic list)
# @return the index where we found the item, or -1 if not found (python should really have this built in)
def searchLines(needle, haystack, deep=False):
    idx = -1
    
    try:
        idx = haystack.index(needle)
    except ValueError:
        pass
    
    if not deep:
        return idx
    
    # Ok - so we want a deep search
    for i, line in enumerate(haystack):
        if needle in line:
            return i
        
    # Should never hit this case, but just in case
    return idx
# End searchLines

# Reads the file in the fileHandle variable -- open the file handle with r+
# @param fileHandle The file handle to read from (seeked back to 0)
# @return A tuple of the file handle and the file's lines or (fileHandle, None) in error
def readFile(fileHandle):
    fileHandle.seek(0)
    fileLines = []
    
    try:
        for line in fileHandle:
            line = line.strip()
            fileLines.append(line)
    
    except IOError:
        return (fileHandle, None)
    
    return (fileHandle, fileLines)
# End readFile

# Writes to the output file in the fileHandle variable
# The file is TRUNCATED pass ALL the lines to write the entire file.
# @param fileHandle the place to write the lines
# @param lines the line to write
# @return a tuple of the fileHandle and True if successful or fileHandle, false otherwise
def writeLines(fileHandle, lines):
    # Truncate the file
    fileHandle.seek(0)
    fileHandle.truncate()
    # Just in case they added extra stuff
    for line in lines:
        line = line.strip()
        line = line + "\n"
        
        try:
            fileHandle.write(line)
        except IOError:
            return (fileHandle, False)
        
    # If we get all the way through, return true
    return (fileHandle, True)
# End writeLines

# Checks the passwords for the given accounts to make sure they are set
# @param accounts A list (or other iterable) of account usernames
# @return A list of accounts with the passwords set
def checkPasswords(accounts):
    retList = []
    
    for account in accounts:
        result = runCommand("passwd " + account + " -S")
        if not result:
            continue
        
        # Should be P as the second arg to indicate that the password is set
        if result[0].split(" ")[1] == "P":
            retList.append(account)
    # Done with looping over accounts
    
    return retList
# End checkPasswords

# A driver for saveconfig - call this and we'll take care of the rest
# @param timeout number of seconds to wait for before quitting, -1 for infinity
# @param prompt Set to false to supress the yes/no prompt
def saveConfigDriver(timeout=-1, prompt=True):
    # If no prompt - fire the script off without the other stuff
    if prompt:
        print(Internet2Consts.RED_BACK + Internet2Consts.WHITE + "**IMPORTANT**" + Internet2Consts.NORMAL + "  Would you like to save your configuration changes so they persist across reboots? [yes]: ")
        sys.stdout.flush() # Force display 
 
        # Might timeout
        if timeout > 0:
            i, o, e = select.select([sys.stdin], [], [], timeout)
            if not i:
                return
        # End timeout blocking code
    
        ans = sys.stdin.readline().strip().upper()
        if not ans:
            ans = "Y" 
        if ans[0] == "N":
            return
    # Done prompting
    if not os.path.isfile(Internet2Consts.SAVEINFO):
        os.system(Internet2Consts.BIN_DIR + "create-drives.py")
    if not os.path.isfile(Internet2Consts.USERINFO):
        getUserInfo(Internet2Consts.USERINFO);
    return
# End saveConfigDriver

# Touches the given file name
# @param fileName The name of the file to touch
def touchFile(fileName):
    os.system("touch " + fileName + " >/dev/null 2>&1")
    return
# End touchFile

# Gets a password from the user
# @param prompt The prompt to show (on confirm it's $prompt (again) DO NOT add a :
# @param confirm Set to True to double check the input
# @param allowBlank Set to True to allow a blank password
# @return The password on success, None otherwise
def getPassword(prompt, confirm, allowBlank):
    pass1 = ""
    pass2 = ""
    
    # Get the first go round
    pass1 = getpass.getpass(prompt + ": ")
    pass2 = pass1
    
    # Get it again
    if confirm:
        pass2 = getpass.getpass(prompt + " (again): ")
        
    if pass1 != pass2:
        return None
    
    if pass1 == "" and not allowBlank:
        return None
    
    return pass1
# End getPassword

def readServicesFile():
    file = Internet2Consts.ENABLEDSERVICESINFO
    variables = {}

    try:
        fileHandle = open(file, "r+")
        fileLines = fileHandle.readlines()
        for line in fileLines:
            line = line.strip()
            (variable, status) = line.split("=", 1)
            variables[variable.strip()] = status.strip();
    except IOError:
        return {}

    return variables 

def writeServicesFile(variables):
    file = Internet2Consts.ENABLEDSERVICESINFO
    try:
        fileHandle = open(file, "w+")

        for variable in variables.keys():
            fileHandle.write(variable + "=" + variables[variable] + "\n")
        fileHandle.close()
    except IOError:
        return -1

    return 0

# Prints out a nice "edited by script" type line
def tagline(script):
    # Read user config file so that we can create a nice comment
    # We don't want to make a new one in this case - force the file to be correct
    user = parseUserInfo(Internet2Consts.USERINFO)

    if user == None:
        return "#%% Updated using " + script + " at time: " + getTimestamp()
    else:
        return "#%% Updated using " + script + " by: " + user.fullName + " -- " + user.emailUser + "@" + user.emailHost + " at time: " + getTimestamp()

# Checks the passwords for the given accounts to make sure they are set
# @param accounts A list (or other iterable) of account usernames
# @return A list of accounts with the passwords set
def checkPassword(account):
    
    result = runCommand("passwd " + account + " -S")
    if not result:
        return False
        
    # Should be P as the second arg to indicate that the password is set
    if result[0].split(" ")[1] == "P":
        return True
    
    return False
# End checkPasswords


