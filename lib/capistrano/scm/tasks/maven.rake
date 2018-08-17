maven_plugin = self

namespace :maven do
  desc "Check that the maven repository is reachable and versioned artifact available"
  task :check do
    on release_roles :all do
      raise "Repo is unreachable" unless maven_plugin.check_repo_is_reachable
      raise "Artifact is unavailable" unless maven_plugin.check_artifact_is_available
    end
  end

  desc "Perform the release"
  task :create_release do
    on release_roles :all do
      maven_plugin.mkdirs
      maven_plugin.download
      maven_plugin.release
    end
  end

  desc "Determine the revision that will be deployed"
  task :set_current_revision do
    on release_roles :all do
      set :current_revision, maven_plugin.fetch_revision
    end
  end
end
