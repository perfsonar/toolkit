#!/usr/bin/python
#
# This script should be called after installing the testpoint bundle.
#
# Author: Sowmya Balasubramanian

from subprocess import call

psBundle=['testpoint','toolkit']
tpPackages=['perl-perfSONAR_PS-Toolkit-ntp','perl-perfSONAR_PS-Toolkit-security','perl-perfSONAR_PS-Toolkit-service-watcher','perl-perfSONAR_PS-Toolkit-sysctl']



def testPointInstall():
    for package in tpPackages:
        print "Would you like to install"+package
        choice = raw_input("y|N: ")
        if(choice == 'y' or choice == 'n'):
            call(['/usr/bin/yum', 'install', package])

###MAIN  
i=1
for bundle in psBundle:
    print str(i)+". "+bundle
    i+=1
  
bundleType = raw_input("Enter bundle type(1,2..): ")
if (bundleType == '1'):
    testPointInstall()
else:
    print "TBD soon!!" 
