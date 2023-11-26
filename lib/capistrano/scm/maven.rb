require "capistrano/scm/plugin"
require "uri"
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'open-uri'


class Capistrano::SCM::Maven < Capistrano::SCM::Plugin
  def set_defaults; end

  def maven_user
    @maven_user ||= begin
      fetch(:maven_user) if fetch(:maven_user)
    end
  end

  def maven_password
    @maven_password ||= begin
      fetch(:maven_password) if fetch(:maven_password)
    end
  end

  def auth_opts
    if maven_user && maven_password
      { http_basic_authentication: [maven_user, maven_password] }
    else
      {}
    end
  end

  def curl_auth
    if maven_user && maven_password
      "'#{maven_user}:#{maven_password}'"
    else
      ''
    end
  end

  def define_tasks
    eval_rakefile File.expand_path("../tasks/maven.rake", __FILE__)
    eval_rakefile File.expand_path("../tasks/clone.rake", __FILE__)
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
      backend.info "Snapshot version found: #{artifact_id}"
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
      backend.info "Remote file name #{remote_filename(artifact_id)}"
      backend.info "Downloading artifact from #{url}"
      if archive_needs_refresh?
        # TODO: redact the curl auth from appearing in logs -or-
        # TODO: use ruby http library to download instead of curl
        # # for example: backend.execute :rake, clone:download
        backend.execute :curl, '--user', backend.redact(curl_auth), '--fail', '--silent', '-o', local_filename, url
      end
  end

  def release
    case fetch(:maven_artifact_ext)
    when 'zip'
      extract_zip(local_filename, release_path)
    when 'tar.gz'
      extract_tarball_gz(local_filename, release_path)
    else
      error = RuntimeError.new("Invalid maven_artifact_ext. Must be one of: zip, tar.gz")
      raise error
    end
  end

  def extract_zip(file_path, destination)
    backend.execute :rm, '-rf', 'out'
    backend.execute :unzip, '-q', file_path, '-d', 'out/'
    backend.execute :bash, "-c 'shopt -s dotglob; mv out/#{fetch(:maven_artifact_name)}-#{fetch(:maven_artifact_version)}/* #{release_path}'"
    backend.execute :rm, '-rf', 'out'
  end

  def extract_tarball_gz(file_path, destination)
    backend.execute :tar, '--strip-components=1', '-xzf', file_path, '-C', release_path
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
    "#{fetch(:maven_artifact_name)}-#{id}-#{fetch(:maven_artifact_classification)}.#{fetch(:maven_artifact_ext)}"
  end

  def local_filename
    "#{repo_path}/#{fetch(:maven_artifact_name)}-#{fetch(:maven_artifact_version)}-#{fetch(:maven_artifact_classification)}.#{fetch(:maven_artifact_ext)}"
  end

  def reachable?(uri_str, limit = 3)
    raise ArgumentError, 'too many HTTP redirects' if limit == 0

    backend.info "Checking #{uri_str} for reachability.."
    uri = URI.parse(uri_str)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Get.new(uri.path)
    request.basic_auth(maven_user, maven_password)

    response = http.request_head(uri.path)


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
    meta = Nokogiri::XML(open(snapshot_metadata_url, :http_basic_authentication => [maven_user,maven_password]))
    versions = meta.xpath('/metadata/versioning/snapshotVersions/snapshotVersion/value')
    versions.first.content if versions
  end
end
