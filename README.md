# Introduction

This repository contains the measures that are used to run the fault models and example cases in the
public report [Development of Fault Models for Hybrid Fault Detection and Diagnostics Algorithm]
(http:// "Link to be added later").

**TO DO: Add citation for report here**

This codebase is a fork of the [OpenStudio Analysis Spreadsheet] project, with modifications. The
structure of the repository is as follows:

* `fault_measures` contains fault model measures that can be used with [OpenStudio] and [OpenStudio
  Analysis Spreadsheet] to model HVAC-related faults in buildings.
* `projects` folder contains [OpenStudio Analysis Spreadsheet] projects that simulate the cases
  described in the technical report.
* `seeds` contains the [OpenStudio] seed models required to run the projects.
* `weather` contains the EnergyPlus weather files required to run the projects.  

Within each of these directories, a README file (`README.md`) provides additional details about the
directory contents. To simplify the repository, the remaining directories from [OpenStudio Analysis
Spreadsheet] have been removed.

[OpenStudio]: https://www.openstudio.net/ "OpenStudio"
[OpenStudio Analysis Spreadsheet]: https://github.com/NREL/OpenStudio-analysis-spreadsheet/ "OpenStudio Analysis Spreadsheet"

# License

OpenStudio Fault Models  
*Main code:* Copyright (c) 2015, Alliance for Sustainable Energy  
*Selected fault measure scripts:* Copyright (c) 2015 Purdue University   
All Rights Reserved.

The OpenStudio fault models are available for use under the Lesser Gnu Public License (LGPL).
See included license files `LICENSE.txt`, `gpl.txt`, and `lgpl.txt` for details.

# Usage Instructions

Because the codebase is a fork of [OpenStudio Analysis Spreadsheet], the general usage instructions
from that project apply. However, there are some modifications, in particular the introduction of a
command line interface. The remainder of this README provides step-by-step instructions for
installing, configuring, and running a project using OpenStudio Analysis Spreadsheet. These
instructions were developed for Windows 7 users on the NREL intranet and contain some elements
applicable only to the NREL network. These steps are explicitly noted in the text.

The instructions provided here are compiled from a variety of sources, including:

* [The OpenStudio Server Project README](https://github.com/NREL/OpenStudio-server/blob/develop/README.md)
* [The OpenStudio Server Vagrant README](https://github.com/NREL/OpenStudio-server/blob/develop/vagrant/README.md)
* [The OpenStudio Server Rails Application README](https://github.com/NREL/OpenStudio-server/blob/develop/server/README.md)
* [The OpenStudio Server Wiki](https://github.com/NREL/OpenStudio-server/wiki)
* [The OpenStudio Analysis Spreadsheet Project README](https://github.com/NREL/OpenStudio-analysis-spreadsheet/blob/master/README.md)

If something doesn't work for you, this README may be out of date and you are encouraged to check
the sources listed above for more recent information.

## Pre-Installation

### Home Directory

The AWS authentication file, as well as the local vagrantbox will be created / built in the
computers' home directory. As a result, ensure that the directory references a disk with significant
room. If you wish to change this (as all NREL users will need to), please follow the instructions
below.

#### (NREL) Windows Users

By default, NREL's active directory policy sets several Windows environment variables, visible
using the command `set home`:

```bat
HOMEDRIVE=U:
HOMEPATH=\
HOMESHARE=\\xhomea\home\[NREL username]
```

`%HOME%` itself is not set by default. To fix this issue do the following:

1. In the Control Panel, go to *System* > *Advanced System Settings* > *Advanced* tab >
   *Environment Variables...*  
   *You will be prompted with the NREL Run as Administrator prompt.*
2. Create a new user environment variable called `HOME` with the value `%USERPROFILE%`. Click *OK*.
3. Reboot.
4. Check your configuration at the command prompt via `set home`. You should now see something
   similar to the following:

```bat
C:\>set home
HOME=C:\Users\jdoe
HOMEDRIVE=U:
HOMEPATH=\
HOMESHARE=\\xhomea\home\jdoe
```

If you have already installed software that put things on the `U:` drive, then you'll also need to
manually copy the relevant folders/files from `U:\` to `C:\Users\[NREL username]`.

#### (NREL) Mac / Linux Users

You can easily check your environment variables from a bash shell. 

```bash
printenv
```

Look for the `HOME` environment variable and ensure it is correct. If not, it can be set by the
following command:

```bash
export HOME=[home_directory_here] #ex /home/jdoe
```

### Proxy Settings

If you are behind a **proxy** then make sure to export the environment variables.  

#### Windows Users

Add the following to your environment variables as instructed above or, if you have administrator
rights, in the command line using the following commands:

```bat
set HTTP_PROXY=proxy.a.com:port  ( e.g. 192.168.0.1:2782 or a.b.com:8080 )
set HTTP_PROXY_USER=user 
set HTTP_PROXY_PASS=password
```

#### Mac / Linux Users

Add the following environment variables in a bash shell.

```bash
export HTTP_PROXY=proxy.a.com:port  ( e.g. 192.168.0.1:2782 or a.b.com:8080 )
export HTTP_PROXY_USER=user 
export HTTP_PROXY_PASS=password
```


### (NREL Only) Developer VPN

Several of the setup steps below require application access through the NREL firewall that involves
checking SSL certificates. Since NREL's firewall modifies SSL certificates, this can cause
application access to fail (silently, with SSL errors, or with more cryptic errors).

To correct this, you must log into and stay on NREL's Developer's VPN using Juno Pulse while on the
NREL campus.

Please note that the Developer VPN access is different from the Internal and External SSL VPN. Since
access to this VPN is controlled send a request to the Service Operation Center in advance if you
intend to use this repository on campus. Sometimes you may need your technical monitor to send the
request, and as a result it may take one or two days before getting the approval.

## Installation Software and Versions

Running an analysis via the OpenStudio Analysis Spreadsheet workflow using a local version of
OpenStudio server requires [VirtualBox], [Vagrant], [Ruby], [OpenStudio Server], and the
[OpenStudio Analysis Spreadsheet]. This setup is covered in the Local Vagrant section. In addition,
you will need a working Git installation. For the purpose of this installation it is assumed that
git is installed and functioning. Please see Chapters One and Two of
[this link](https://git-scm.com/doc) if this is not the case.

[VirtualBox]: https://www.virtualbox.org/
[Vagrant]: http://www.vagrantup.com/
[Ruby]: https://www.ruby-lang.org/en/
[OpenStudio Server]: https://github.com/NREL/OpenStudio-server/
[OpenStudio Analysis Spreadsheet]: https://github.com/NREL/OpenStudio-analysis-spreadsheet
[ChefDK]: https://downloads.chef.io/chef-dk/

**This repository currently does not work with Ruby 2.2.**

This README was developed using Windows 7 x64 and the following software versions:

**TO DO: Update these software versions**

Software                         | Version               | Download Link
:------------------------------- | :-------------------- | :--------------
VirtualBox                       | 4.3.8 (64-bit)        | Download [here](https://www.virtualbox.org/wiki/Download_Old_Builds_4_3)
Vagrant                          | 1.7.2 (64-bit)        | Download [here](http://www.vagrantup.com/downloads.html)
Ruby                             | 2.0.0-p353 (32-bit)   | Download [this exact installer](http://dl.bintray.com/oneclick/rubyinstaller/#rubyinstaller-2.0.0-p353.exe)
OpenStudio Server                | ???                   | Clone [this repository](https://github.com/NREL/OpenStudio-server)
OpenStudio Analysis Spreadsheet  | 0.4.4                 | Clone [this repository](https://github.com/NREL/OpenStudio-analysis-spreadsheet)
ChefDK                           | 0.5.0                 | Download [here](https://downloads.chef.io/chef-dk)

This software has also been executed on Ubuntu 14.04 LTS using the following software versions:

Software                         | Version                       | Download Link
:------------------------------- | :---------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
VirtualBox                       | 4.3.10 (Ubuntu)               | Download [here](https://www.virtualbox.org/wiki/Download_Old_Builds_4_3)
Vagrant                          | 1.7.2 (Debian)                | Download [here](http://www.vagrantup.com/downloads.html)
Ruby                             | 2.0.0-p384 (x86_64-linux-gnu) | Download [this  tar.gz](http://cache.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-rc2.tar.gz) and make as specified [here] (http://stackoverflow.com/questions/16222738/how-do-i-install-ruby-2-0-0-correctly-on-ubuntu-12-04)
OpenStudio Server                | ???                           | Clone [this repository](https://github.com/NREL/OpenStudio-server)
OpenStudio Analysis Spreadsheet  | ???                           | Clone [this repository](https://github.com/NREL/OpenStudio-analysis-spreadsheet)
ChefDK                           |  0.3.5                        | Download [here] (https://downloads.chef.io/chef-dk)


Other versions will probably also work, but no guarantees. It is recommended that Linux users use
the defaults of their repository management system. These defaults have been found to work well so
far. Mac installations will differ; see the README files linked above for differences.

## Required Instillation Software

### Ruby

#### Windows Users

* Install Ruby 2.0.0-p481 (32-bit) via the exact link above.  
  *This is the exact version specified in the original README; it's uncertain whether other 2.0.0
  versions will work ok, although in theory they might.*
* Put Ruby on your Windows path.  
  *There's a convenient Windows utility called [Pik](https://github.com/vertiginous/pik) that can
  help you manage multiple Ruby versions.*
* Verify your ruby version via the command line:

```bat
C:\>ruby -v
ruby 2.0.0p481 (2013-11-22) [i386-mingw32]
```

#### Mac / Linux Users

In a bash shell type `ruby -v` to see the version currently being used. If the version is not
`ruby 2.0.0**` use the links above to download and install ruby 2.0.0. Consider using
[rbenv](https://github.com/sstephenson/rbenv) if multiple versions of Ruby need to be maintained on
your machine. 

### OpenStudio Analysis Spreadsheet

If you are an NREL user, see note below before proceeding.

* Git clone this repository: https://github.com/NREL/FDD-OpenStudio

```sh
git clone git@github.com:NREL/FDD-OpenStudio.git
```

* Install RubyGem's Bundler.

```sh
gem install bundler
```

* Install the project dependencies.

```sh
bundle
```

#### (NREL Only) Access Requirements

  * Log in to the Developer's VPN through Juno Pulse so that
  Ruby can access [https://rubygems.org](https://rubygems.org) (more secure),
  * Or change Ruby's gem source to [http://rubygems.org](http://rubygems.org) (less secure):

```sh
gem sources -r https://rubygems.org/
gem sources -a http://rubygems.org/
```

## How To: Amazon Web Services

Once an Amazon Web Services (AWS) account is created and set up it is critical to correctly
configure the account access setting to allow the job to be submitted to AWS.

### Setting Up an Account

1. Begin by going to [AWS] (http://aws.amazon.com). Click the Sign Up button in the top right
   corner.
2. Enter your email or mobile number and click *I am a new user.* before clicking on the *Sign in*
   button.
3. Be aware while progressing through the next screens that it is important to use strong passwords,
   as malicious activity can easily go undetected. Additionally it is important to provide Amazon
   with a phone number you are accessible at so you can be reached in case of potentially fraudulent
   activity on your account.
4. When you reach 'aws.amazon.com/registration-confirmation' click on the Launch Management Console
   button, which should redirect you to 'console.aws.amazon.com/console/home'. Under *Administration
   & Security* click on *Identity & Access Management.* See the links for setting up
   [an MFA](http://docs.aws.amazon.com/IAM/latest/UserGuide/Using_ManagingMFA.html),
   [non-root user](http://docs.aws.amazon.com/IAM/latest/UserGuide/Using_SettingUpUser.html),
   [non-root group permission](http://docs.aws.amazon.com/IAM/latest/UserGuide/GSGHowToCreateAdminsGroup.html),
   and [using the management console](http://docs.aws.amazon.com/awsconsolehelpdocs/latest/gsg/getting-started.html).
   **It is critical to complete all five items listed under Security Status.**
5. **Download, Screenshot, and save your Access Key ID and Secret Access Key when creating a IAM
   User. These will never again be available to you.**  
   *When creating an individual IAM user it is recommended that Internet Explorer not be used, as
   there is a known bug on the page only experienced by IE users.

Once all five steps have been completed, consider using an [alias]
(http://docs.aws.amazon.com/IAM/latest/UserGuide/AccountAlias.html) for your user account and log
into your non-root account. 

### Using the Command Line Interface with AWS

Attempt to run a project using the Command Line Interface (CLI) using the directions at the end of
this document. An error message should be generated to the effect of 'No Config File in the user
home directory.' Go to your home directory and look for a file named `aws_config.yml`. Open this
file in a text editor, and add your access key id and secure access key in the indicated places.
Save the file.

Finally, create / set an environment variable `AWS_DEFAULT_REGION` to `us-east-1` as described above
for your operating system. 

You should now be able to use the CLI with the `aws` target.

## How To: Vagrant

These instructions were originally written for Windows users, but should apply to any OS.

### Required Software

#### VirtualBox

Install the VirtualBox associated with your OS.

#### Vagrant

* Install Vagrant via the installer
* Reboot (required for Vagrant install)
* Log in to the NREL Developer's VPN through Juno Pulse
* Install vagrant plugins (requires VPN or will fail to locate the plugin):
  * `vagrant plugin install vagrant-omnibus`
  * `vagrant plugin install vagrant-aws`
  * `vagrant plugin install vagrant-vbguest`  
    *Optional; useful if you are using Virtualbox 4.3+ to update the guest version.*

#### OpenStudio Server

* Git clone this repository: https://github.com/NREL/OpenStudio-server

```sh
git clone git@github.com:NREL/OpenStudio-server.git
```

* Initialize and update all Git submodules

```sh
git submodule init
git submodule update
```

#### ChefDK

* Download ChefDK at [https://downloads.chef.io/chef-dk/] (https://downloads.chef.io/chef-dk/)

* Open the downloaded file and follow the instructions.

### Configuration

This section documents initial setup of the OpenStudio server VMs. You will need to do these steps
once, unless you destroy the VM (manually delete or `vagrant destroy`) or need to update to a new
version of the repository. 

*Begin by cloning the [OpenStudio-server](http://github.com/NREL/OpenStudio-server) github
repository. The following instructions assume the repository to be cloned to the default directory
`OpenStudio-server`.
* In your home directory, make a new folder named `.aws`.
* Copy the below text into a text editor. Note that entering your real credentials and information
  is not required for either using the vagrant box locally or using AWS as described above.

```bash
access_key_id: thisIsntMyAccessKey
secret_access_key: thisIsntMySecretKey
region: what-is-region
keypair_name: thisIsA.name
private_key_path: home/.ssh
```
* Save this file as `config.yml` in the `.aws` folder.

#### (NREL Only) Other Considerations

Throughout this process you may be prompted one or more times with the *NREL Run as Administrator*
prompt as VirtualBox sets up the network interface. Enter you network account password to proceed.
In the case of Mac users be sure to use the NREL administrator script. If the steps below take
longer to run than your administrator privilege last for, re-enable the administrator privilege and
enter the command `vagrant provision`. If using a Linux distribution simply preface all commands
with `sudo`.

Note that you will need to be logged in to the NREL Developer's VPN through Juno Pulse throughout
this process in order for the VM to get access to required resources on the Internet. In particular,
if you see network-, ruby-, SSL Certificate, or or omnibus-related errors, check that you are logged
in to the VPN.

#### Configuring the Cluster

* Launch a command window / bash shell in `OpenStudio-server/vagrant/server/`.
* Run command `berks` to update your ChefDK cookbook
* Start the VM and let it provision: `vagrant up`
  * If provisioning fails, try the command `vagrant provision` a few times; it may succeed on
    subsequent tries.
  * This step may take a long time (hours) depending on the speed of your internet connection.
  
#### Configuring a Worker

These instructions are for the first worker (`worker`). To spawn multiple workers, repeat for
`worker_2` and `worker_3`.

* Ensure that the server is fully provisioned prior to provisioning any workers.
* Launch a command window / bash shell in `OpenStudio-server/vagrant/worker/`.
* Run command `berks` to update your ChefDK cookbook
* Start the VM and let it provision: `vagrant up`
  * If provisioning fails, try the command `vagrant provision` a few times; it may succeed on
    subsequent tries.
  * This step may take a long time (hours) depending on the speed of your internet connection.

### Launch the Cluster

In contrast to the previous section, the steps in this section must be completed each time you wish
to (re)start the VM's in the cluster.

#### Launch the Server

* Launch a command window in `OpenStudio-server/vagrant/server/`.
* If the server is not currently running, bring it up using `vagrant up`.
  
#### Launch the Worker(s)

For each worker:

* Launch a command window in `OpenStudio-server/vagrant/worker[_N]/`, where `[_N]` corresponds to
  the suffix required for workers after the first worker.
* If the worker is not currently running, bring it up using `vagrant up`.

#### Run Configuration Scripts

Complete these steps after launching the server and worker VMs, as they require communication among
the VMs.

* Access the server bash shell either by running `vagrant ssh` in `OpenStudio-server/vagrant/server`
  or by using the PuTTy tool.
* Run the command `cs`. *This command launches the server configuration script and queries for the
  presence of workers.*
* Access each worker's bash shell either by running `vagrant ssh` in
  `OpenStudio-server/vagrant/worker[_N]` or by using the Putty tool.
* Run the command `cw`. *This command launches the worker configuration script.*

**If you are only launching a server instance, run both `cs` and `cw` in that server box's bash
shell.**

### Running the CLI with Vagrant

You should now be able to use the CLI with the `vagrant` target as described in the Using the CLI
section below.

## Troubleshooting

* Be sure that the correct version is running on your path when you run the OpenStudio Analysis
Spreadsheet commands. Check by opening a command prompt or bash shell in the OpenStudio-fault-models
Directory and running `ruby -v`.

## Updating Software

### VirtualBox

To do a clean update of VirtualBox, with removal of previous settings and VMs:

* Uninstall VirtualBox (via *NREL Run as Administrator/Program Manager* )
* Delete the following from your home directory `~`:
  * `.VirtualBox` (directory)
  * `VirtualBox VMs` (directory)
* Install the new version.
* You may need to reboot and reconfigure / reset Vagrant to recognize the new VirtualBox
  configuration.

### Vagrant

To do a clean update of Vagrant, with removal of previous settings:

* Uninstall Vagrant (via *NREL Run as Administrator/Program Manager* )
* Reboot (required for Vagrant uninstall)
* Delete the following from your home directory `~`:
  * `.vagrant` (directory)
  * `.vagrant.d` (directory)
  * `Vagrantfile`
* In addition, you may wish to delete the `.vagrant` directories for any VMs you previously created.
  These are typically located in the same directory as the `Vagrantfile` used to provision the VM.
* Install the new version.
* Reboot (required for Vagrant install).

### Ruby

If updating Ruby and / or managing multiple versions of Ruby, be sure that the correct version is on
your path when you run the OpenStudio Analysis Spreadsheet commands.

### OpenStudio Server

To update:

* Pull an updated version of the Git repository:

```sh
git pull
```

* Update the Git submodules to match:

```sh
git submodule update
```

### OpenStudio Analysis Spreadsheet

To update:

* Set a git remote called `upstream` to the [OpenStudio Analysis Spreadsheet] repo
* Fetch an updated version of the Git repository:

```sh
git fetch upstream [branch]
```

* Merge upstream changes (may require manual intervention in the case of deleted files):

```sh
git merge upstream/[branch]
```

* You may need to re-execute `bundle` per the installation instructions

### ChefDK

To update:

* Install new version of ChefDK
  * Uninstall CheckDK at Control Panel
  * Install the new version
  * The progress bar of the uninstillation process may not move for half an hour. Please be patient.

* Update cookbooks
  * In the directory containing files Vagrantfile and Berksfile, run

```sh
berks update
```

## The Command Line Interface

The command line interface (CLI) operates much like a traditional Unix command line program. To run
the CLI use the base string `bundle exec ruby cli.rb` in the cloned FDD-OpenStudio folder. Using the
`-h` tag displays help for using the CLI.

```sh
 >bundle exec ruby cli.rb -h
 
 Usage:    bundle exec ruby cli.rb [-t] <target> [-p] <project> [-d] <download> [-s] [-k] [-o] [-h]
    -t, --target SERVER              target OpenStudio SERVER instance
    -p, --project FILE               specified project excel FILE
    -d, --download DIRECTORY         specified DIRECTORY for downloading results RDataframes and csv files
    -r, --rdataframe,                download rdataframe results and metadata files
    -c, --csv,                       download csv results and metadata files
    -z, --zip DIRECTORY              specified DIRECTORY for downloading zip result files
    -s, --stop                       stop server once completed
    -k, --kill                       kill server once completed
    -o, --override_safety            allow KILL without DOWNLOAD or allow server to not shutdown
    --server-wait INTEGER            seconds to wait for job to start before timeout. Default 1800.
    --analysis-wait INTEGER          seconds to wait for job to complete before timeout. Default 1800.
    -h, --help                       display help

```

**Be aware that -k only works on AWS instances, and is not a sure way of terminating instances.
Always check your EC2 dashboard to ensure you instances are stopped. Be aware that only instances in
the selected region are displayed. To change view to a different region click on the button to the
left of Support in the upper right corner of the screen.**

To add additional targets follow the provided standard in `lookup_target_url` method. Current
targets are 'aws' and 'vagrant', as well as 'nrel24', 'nrel24a', and 'nrel24b' for those logged
onto the Developer VPN. 

### Example

A person wants to simulate the cases in the project `projects/case2012_ec_waterchiller_report.xlsx`
with AWS service. The person would like to download all .RData files, .csv files
and .zip files upon completion, and it is estimated that the simulation will
complete between 1800s and 7200s. After setting up the AWS account and set up
the local AWS information in the home directory, the person can use the
following command to achieve the operation.

```sh
 >bundle exec ruby cli.rb -p projects/case2012_ec_waterchiller_report.xlsx -t aws -o -r -c -z --analysis-wait 7200
```

