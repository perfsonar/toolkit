#!/usr/bin/python
#
# This script should be called after installing the testpoint bundle.
#
# Author: Sowmya Balasubramanian

import os
import sys

bindir = os.path.abspath(os.path.dirname(os.path.realpath(sys.argv[0])))
libdir = os.path.join(bindir, "..", "python_lib")

sys.path.append(libdir)

import yum
import Internet2Lib
import Internet2Consts

optionalPackages=[
    'perfsonar-toolkit-ntp',
    'perfsonar-toolkit-security',
    'perfsonar-toolkit-servicewatcher',
    'perfsonar-toolkit-sysctl'
]

def installPackages(yumHandle, packageNames):
    userChoice=[]
    for package in packageNames:
        print "\nWould you like to install "+package+"?"
        choice = raw_input("\nEnter y|N: ")
        if(choice == 'y' or choice == 'Y'):
            userChoice.append(package)
    
    for package in userChoice:
        print "Installing "+package
        try:
            yumHandle.install(name=package)
        except yum.Errors.InstallError, err:
            print "Error installing package"+str(err)

    if userChoice:
        yumHandle.resolveDeps()
        yumHandle.processTransaction()
        print "\n Installed the following packages: \n"
        for package in userChoice:
            print package

def findInstalledPackages(yumHandle, packageNames):
    toInstall = []
    for package in packageNames:
        if not yumHandle.rpmdb.searchNevra(name=package):
            toInstall.append(package)
            print package
    return toInstall
    
###MAIN 
yHandle = yum.YumBase();
if not Internet2Lib.isRoot():
    print Internet2Consts.YELLOW + "You must run the perfSONAR install-optional-packages script as root." + Internet2Consts.NORMAL
    sys.exit(1)

#find what packages need to be installed
packagesToInstall = findInstalledPackages(yHandle, optionalPackages)

if packagesToInstall:
    installPackages(yHandle, packagesToInstall)
else:
    print "All optional packages have been installed \n"
    for package in optionalPackages:
        print package
