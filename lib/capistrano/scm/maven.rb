require "capistrano/scm/plugin"
require "uri"
require 'net/http'
require 'nokogiri'
require 'open-uri'

class Capistrano::SCM::Maven < Capistrano::SCM::Plugin
  def set_defaults; end

  def define_tasks
    eval_rakefile File.expand_path("../tasks/maven.rake", __FILE__)
  end

  def register_hooks
    after "deploy:new_release_path", "maven:create_release"
    before "deploy:check", "maven:check"
    before "deploy:set_current_revision", "maven:set_current_revision"
  end

  def fetch_revision
    fetch(:maven_artifact_version)
  end

  def check_repo_is_reachable
    reachable?(repo_url)
  end

  def check_artifact_is_available
    if snapshot_artifact?
      reachable?(snapshot_metadata_url)
    else
      reachable?(artifact_url)
    end
  end

  def mkdirs
    backend.execute :mkdir, "-p", repo_path
    backend.execute :mkdir, "-p", release_path
  end

  def download
    url = artifact_url(artifact_id)
    backend.info "Downloading artifact from #{url}"
    if archive_needs_refresh?
      backend.execute :curl, '--fail', '--silent', '-o', local_filename, url
    end
  end

  def release
    backend.execute :tar, '-xzf', local_filename, '-C', release_path
  end

  private

  def archive_needs_refresh?
    true
  end

  def snapshot_artifact?
    fetch(:maven_artifact_version).include? 'SNAPSHOT'
  end

  def artifact_missing?
    backend.test(" [ ! -f #{local_filename} ] ")
  end

  # The trailing slash on the URL avoids a 302 Not Found response from
  # Artifactory. The #reachable? methods supports this type of
  # redirect but adding the trailing slash saves a step.
  def repo_url
    "#{fetch(:maven_endpoint)}/#{maven_repository}/"
  end

  def maven_repository
    if snapshot_artifact?
      fetch(:maven_snapshot_repository)
    else
      fetch(:maven_release_repository)
    end
  end

  # Full path to artifact
  def artifact_url(id = nil)
    "#{artifact_directory_url}/#{remote_filename(id)}"
  end

  # Full path to snapshot's maven-metadata.xml
  def snapshot_metadata_url
    "#{artifact_directory_url}/maven-metadata.xml"
  end

  # Path to version directory that contains the artifact
  def artifact_directory_url
    [
      fetch(:maven_endpoint),
      maven_repository,
      *fetch(:maven_group_id).split('.'),
      fetch(:maven_artifact_name),
      fetch(:maven_artifact_version)
    ].join('/')
  end

  def remote_filename(id)
    id = fetch(:maven_artifact_version) if id.nil?
    "#{fetch(:maven_artifact_name)}-#{id}-#{fetch(:maven_artifact_style, 'cap')}.#{fetch(:maven_artifact_ext)}"
  end

  def local_filename
    "#{repo_path}/#{fetch(:maven_artifact_version)}.#{fetch(:maven_artifact_ext)}"
  end

  def reachable?(uri_str, limit = 3)
    raise ArgumentError, 'too many HTTP redirects' if limit == 0

    backend.info "Checking #{uri_str} for reachability.."
    uri = URI(uri_str)
    response = Net::HTTP.new(uri.host, uri.port).request_head(uri.path)

    case response
    when Net::HTTPSuccess then
      backend.info "#{uri_str} is reachable"
      true
    when Net::HTTPRedirection then
      location = response['location']
      warn "redirected to #{location}"
      reachable?(location, limit - 1)
    else
      false
    end
  end

  # If the artifact is a timestamped snapshot the artifact identifier is returned.
  # Otherwise, nil is returned.
  def artifact_id
    return unless snapshot_artifact?
    meta = Nokogiri::XML(open(snapshot_metadata_url))
    versions = meta.xpath('/metadata/versioning/snapshotVersions/snapshotVersion/value')
    versions.first.content if versions
  end
end
