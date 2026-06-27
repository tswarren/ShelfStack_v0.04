# frozen_string_literal: true

module SystemTestDriver
  module_function

  def configure_selenium!
    ENV["SE_DISABLE_DRIVER_MANAGER"] = "1" if chromedriver_path
  end

  def chrome_binary
    ENV["CHROME_BIN"].presence ||
      %w[/usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome].find { |path| File.exist?(path) }
  end

  def chromedriver_path
    ENV["CHROMEDRIVER_PATH"].presence ||
      %w[/usr/bin/chromedriver /usr/lib/chromium/chromedriver].find { |path| File.exist?(path) }
  end

  def chrome_options
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1400,1400")
    options.binary = chrome_binary if chrome_binary

    options
  end

  def register!
    configure_selenium!

    Capybara.register_driver :shelfstack_headless_chrome do |app|
      driver_args = {
        browser: :chrome,
        options: chrome_options
      }

      if chromedriver_path
        driver_args[:service] = Selenium::WebDriver::Chrome::Service.new(path: chromedriver_path)
      end

      Capybara::Selenium::Driver.new(app, **driver_args)
    end
  end
end
