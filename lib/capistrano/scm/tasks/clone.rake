
require 'down'
require 'http'
require 'zip'
require 'progressbar'

Down.backend :http # use the Down::Http backend

namespace :clone do

  desc "Rake task to download the artifact"
  task :download, :url, :user, :password, :destination do |t, args|

    url = args[:url]
    user = args[:user]
    password = args[:password]
    destination = args[:destination]

    backend.info local_filename
    uri = URI.parse(url)

    backend.info "down uri to string " + uri.to_s
    http = Down::Http.new { |client|
      client.basic_auth(:user => user, :pass => password)
    }
    progressbar = ProgressBar.create(:title => "Bytes")
    http.download uri.to_s,
                  destination: destination,
                  content_length_proc: -> (content_length) { progressbar.total = content_length },
                  progress_proc:       -> (progress) { progressbar.progress = progress }
  end

  desc "Rake task to upack the downloaded file"
  task :unpack, :file_path, :destination do |t, args|
      file_path = args[:file_path]
      destination = args[:destination]

      FileUtils.mkdir_p(destination)
      backend.info "file: #{file_path} and destination #{destination}"

      Zip::ZipFile.open(file_path) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
      }

  end
end