# perfSONAR Toolkit Next Generation

This repository contains scripts and GUIs included with the Toolkit distribution of perfSONAR. A Toolkit includes a full operating system with a consistent environment in terms of default system tunings, firewalls, and software configurations. It also includes GUIs used to manage the Toolkit system and display measurement results. 

To use the Next Generation web UI, checkout the "toolkit-ng" branch

##Getting the Code
You may checkout the code with the following command:

```
git clone --recursive https://github.com/perfsonar/toolkit.git
```

Note the use of the `--recursive` option to ensure any submodule trees are included in the clone.

##Building and Installing

To install the code on your system run:

```bash
make install
```

##Packaging
You may create a source tarball of this code with the following:

```bash
make dist
```

##Using the *shared* Submodule
This repository contains a [git submodule](http://git-scm.com/book/en/v2/Git-Tools-Submodules) to the perfSONAR [shared](https://github.com/perfsonar/perl-shared) repository. This submodule is used to access common perfSONAR libraries. You will find a number of symbolic links to these modules under *lib*. The use of a submodule has a few implications when working with the code in this repository:

* As previously noted, when you clone the repository for the first time, you will want to use the `--recursive` option to make sure the submodule tree is included. If you do not, any symbolic links under *lib* will be broken in your local copy. If you forget the `--recursive` option, you can pull the submodule tree with the following commands:

    ```bash
    git submodule init
    git submodule update
    ```
* When you are editing files under *lib* be sure to check if you are working on an actual file or whether it's a link to something under *shared*. In general it is better to make changes to the *shared* submodule by editing the *shared* repository directly. If however you do make changes while working in this repository, see the [git submodule page](http://git-scm.com/book/en/v2/Git-Tools-Submodules#Working-on-a-Project-with-Submodules) for more details on pushing those changes to the server.
* Keep in mind that a submodule points at a specific revision of the repository it is referencing. As such if a new commit is made to the shared submodule's repository, this project will not get the change automatically. Instead it will still point at the old revision. To update to the latest revision of the *shared* submodule repository run the following commands:

    ```bash
    git submodule foreach git pull origin master
    git commit -a -m "Updating to latest shared"
    git push
    ```
* If you want to include a new file from the *shared* submodule, create a symbolic link under *lib*. For example, if you were to add a reference to the  *perfSONAR_PS::Utils::DNS* module you would run the following:

    ```bash
    mkdir -p lib/perfSONAR_PS/Utils/
    cd lib/perfSONAR_PS/Utils/
    ln -s ../../../shared/lib/perfSONAR_PS/Utils/DNS.pm DNS.pm
    ```
For more information on using the submodule, see the *shared/README.md* file or access it [here](https://github.com/perfsonar/perl-shared/blob/master/README.md) 

