# Capistrano SCM Maven #

A Capistrano SCM plugin is supposed to be a client of a proper Source
Control system, right? Well, what if you're working in a compiled
language and your source has already been versioned and a compiled
artifact made from it? That's where this plugin comes in. It complies
with the interface of an SCM plugin (pretty well, I think) but the
"repo" is a tarball that contains your application.

I chose Maven for the name because it is the artifact repository
standard that Maven created (and Artifactory and Nexus both
implement). I doesn't refer to building Java source with the Maven's
mvn tool. Thanks to [jmpage's Capistrano SCM Nexus
plugin](https://github.com/jmpage/capistrano_scm_nexus) for ideas and
reference, which in some cases resulted in outright theivery.

## Background ##

My team is made up of Java developers and Ruby developers. Looking
over the fence from the Java side of things, I was jealous of the Ruby
team's ability to use Capistrano - a great automated deployment
tool. Some of our Java projects use Python's Fabric which is very nice
but it's the only python tool we use. So, in the interest of
standardizing on one tool, especially with an eye for automating
deploys in a similar way in a Gitlab pipeline, I decided to see if
Capistrano would work for Java deployments.

## Notes ##

(differences from other SCM plugins)

1. Because we're deploying a binary tarball, the directory structure
within the artifact is important. In short, __it needs to match the
final expanded directory structure to work__. I call this structure
the `maven_artifact_style` and default it to 'cap'. For Java projects,
this means that the executable jar within the tarball should not have
the version on it so scripts and/or systemd can find it
consistently. In fact nothing in the tarball should be versioned. This
doesn't cause version confusion because the tarball is versioned and
the extracted version of the executable jar will already be contained
within a specific release in the normal Capistrano releases
directory. I discuss below how to use Maven's Assembly plugin to
create a tarball artifact compliant with this gem.

1. When I refer to the term repo in this documentation, I mean the
artifact repository. But in the plugin framework code, repo means the
artifact contents.

## Features ##

* Supports separate release and snapshot repositories. This is needed
  in Artifactory (I don't know anything about Nexus but supposedly
  should be useful there too).
* Downloads the artifact from repo only if archive is a snapshot or is
  a release and not present already
* Supports non-standard repo ports
* Supports 302 redirects from the repo

## Install ##

Install the gem manually:

    gem install capistrano-scm-maven

or add it to your `Gemfile` when using Bundler:

    gem 'capistrano-scm-maven'


## Configure ##

Require the gem in your `Capfile`:

    require 'capistrano_scm_maven'
        
or
    require 'capistrano/scm/maven'
    install_plugin Capistrano::SCM::Maven

Configure the gem's variables

```ruby
set :maven_endpoint, 'http://agoodno.com:8081/artifactory'
set :maven_repository, 'libs-snapshot'
set :maven_group_id, 'com.agoodno'
set :maven_artifact_version, '0.0.1-SNAPSHOT'
set :maven_artifact_name, 'sample'
set :maven_artifact_style, 'cap'
set :maven_artifact_ext, 'tar.gz'
```

The configuration above would result in an attempt to retrieve the
artfact at:

    `http://agoodno.com:8081/artifactory/libs-snapshot/com/agoodno/sample/0.0.1-SNAPSHOT/sample-0.0.1-SNAPSHOT-cap.tar.gz`

## Build Artifact ##

### Add assembly plugin

Add [Maven's Assembly
Plugin](https://maven.apache.org/plugins/maven-assembly-plugin/) to
your Maven POM file.

__pom.xml__
``` xml
  ...
  <build>
    <plugins>
      ...
      <plugin>
        <artifactId>maven-assembly-plugin</artifactId>
        <version>3.1.0</version>
        <configuration>
          <descriptors>
            <descriptor>src/assembly/cap.xml</descriptor>
          </descriptors>
        </configuration>
        <executions>
          <execution>
            <id>make-assembly</id>
            <phase>package</phase>
            <goals>
              <goal>single</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
  ...
```

### Create the assembly file

The assembly file referenced in the POM above describes how to build
the tarball with your application's final directory structure. Setting
`includeBaseDirectory` to `false` below removes the versioned
container directory that is created by default. Also, `destName` is
set to remove the version from the aplication jar. I've only added a
README.md in addition to the application jar. See the Assembly
plugin's documentation to build out your application's whole
structure.

__src/assembly/cap.xml__
``` xml
<?xml version="1.0" encoding="UTF-8"?>
<assembly xmlns="http://maven.apache.org/plugins/maven-assembly-plugin/assembly/1.1.2"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/plugins/maven-assembly-plugin/assembly/1.1.2 http://maven.apache.org/xsd/assembly-1.1.2.xsd">
  <id>cap</id>
  <formats>
    <format>tar.gz</format>
  </formats>
  <includeBaseDirectory>false</includeBaseDirectory>
  <files>
    <file>
      <source>target/${artifactId}-${version}.${packaging}</source>
      <destName>${artifactId}.${packaging}</destName>
    </file>
    <file>
      <source>README.md</source>
    </file>
  </files>
</assembly>
```

## Verify ##

You can verify that the gem is installed by listing the tasks
available to capistrano with:

    cap -T

You should see 3 maven namespaced commands in the list.


## Run ##

Because this gem takes part in the normal capistrano deploy lifecycle,
to run it just run the deploy task as you normally would:

    cap staging deploy
