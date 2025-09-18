#!/bin/sh

set -e

adduser --disabled-password --gecos "" autopkgtest2
adduser autopkgtest2 pssudo
echo autopkgtest2:autopkgpass | chpasswd

cat > $AUTOPKGTEST_TMP/askpass <<EOF
#!/bin/sh
echo autopkgpass
EOF
chmod +x $AUTOPKGTEST_TMP/askpass

su -c "SUDO_ASKPASS=$AUTOPKGTEST_TMP/askpass sudo -A id" autopkgtest2 2>&1 \
| grep root
