# Capistrano SCM Maven #

TODO: add info here about:

* Audience for this gem, my team's environment and need.
* Binary distribution style (named -cap.tar.gz here) that is tarred
without version in jar name. The maven assembly that constructs a
compliant tarball.
* Support for Artifactory-specific releases and snapshots
* Download from repo only if archive is a snapshot or is a release but
  not present already
* Support for non-standard port
* Support for 302 redirects
* Explain why I chose Maven for the name

## Install ##

Install the gem manually:

    gem install capistrano-scm-maven

or add it to your Gemfile when using Bundler:

    gem 'capistrano-scm-maven'


## Configure ##

Require the gem in your `Capfile`:

    require 'capistrano_scm_maven'

Configure the gem's variables

```ruby
set :maven_endpoint, 'http://artifactory.agoodno.com:8081/artifactory'
set :maven_repository, 'libs-snapshot'
set :maven_group_id, 'com.agoodno'
set :maven_artifact_version, '0.0.1-SNAPSHOT'
set :maven_artifact_name, 'sample'
set :maven_artifact_style, 'cap'
set :maven_artifact_ext, 'tar.gz'
```

## Run ##

You can verify that the gem is installed by listing the tasks available to capistrano:

    cap -T

Because this gem takes part in the normal capistrano deploy lifecycle,
to test it just run the deploy task as you normally would:

    cap staging deploy

## Notes ##

Thanks to [jmpage's Capistrano SCM Nexus plugin](https://github.com/jmpage/capistrano_scm_nexus) for ideas and
reference.
