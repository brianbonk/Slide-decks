# Install SQL server 2022 from command line


>## This is only for development and testing purposes, also hence the configuration files content.

This doucment describes the fastest approach to install SQL server 2022 from CLI.

## Download binaries

Go to this [link]I(https://info.microsoft.com/ww-landing-sql-server-2022.html) and sign up for a preview. 

After committing the input, you'll be granted access to download the small EXE-file.

Download this file and start it by double clicking on it.

## Download the binaries
To download the binaries for fast install, you hae to choose the option named "Download Media".

Choose your settings and make sure to choose the ISO (that is default) version of the file.

The media is downloaded as an ISO to the selected folder.

## Mount the ISO
To mount the ISO simply just double click the ISO file and it is mounted to your machine as a new drive.

## Download the provided config-file 
To use an allready existing config-file you can download it from [here](ConfigurationFile.ini)

### Alter the file
Make sure to alter the file at line 174 and 210. You need to provide your own Azure AD login name.

If you are unsure that that is - you can always run this line in your command line interface:

```cmd
c:\>whoami
```

## Install the SQL server 2022 with one line of code on your CLI
Open a command line and use this line - just copy, make the changes and execute:

```cmd
c:\> [path1]\setup.exe /ConfigurationFile="[path2]\MyConfigurationFile.INI"
```

The following variables needs to be changed:

- path1: the path to your ISO mount - normally that is D:
- path2: the path to the just downloaded config.file

## NOTES
The config file is intended for development at testing only. 

It does not concain setup for Azure Arc and all services are configures to use the built in SYSTEM service account - this to remove any obstacles when testing the version.

