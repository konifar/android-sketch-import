require 'circleci'
require 'open-uri'

class FetchSketchImages

  IMAGES_FILE = 'images.zip'
  GITHUB_USER_NAME = 'konifar'
  GITHUB_REPO = 'android-sketch-import'

  def initialize(circle_ci_token)
    @circle_ci_token = circle_ci_token

    CircleCi.configure do |config|
      config.token = @circle_ci_token
    end
  end

  def fetch(build_no)
    images = []
    retry_count = 0
    sleep_secs = 0
    while images.size == 0 and retry_count < 10
      sleep sleep_secs
      STDERR.puts "#{retry_count}: Fetch artifact data."
      images = circle_ci_images_info(build_no)
      retry_count += 1
      sleep_secs += 30
    end
    raise "#{IMAGES_FILE} not found." if retry_count >= 10

    url = images[0]['url'] + '?circle-token=' + @circle_ci_token
    File.open(IMAGES_FILE, 'wb') do |saved_file|
      open(url, 'rb') do |read_file|
        saved_file.write(read_file.read)
      end
    end
  end

  private
  def circle_ci_images_info(build_no)
    res = CircleCi::Build.artifacts GITHUB_USER_NAME, GITHUB_REPO, build_no
    raise res.to_s unless res.success?

    res.body.select { |item|
      item['pretty_path'] == '$CIRCLE_ARTIFACTS/images.zip'
    }
  end
end

circle_ci_token = ARGV[0]
build_no = ARGV[1]

FetchSketchImages.new(circle_ci_token).fetch(build_no)
