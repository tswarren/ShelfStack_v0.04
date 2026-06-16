# frozen_string_literal: true

require "test_helper"

class SetupBisacSubjectsControllerTest < ActionDispatch::IntegrationTest
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/bisac_sample.csv").to_s

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "bisacadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.bisac_subjects.view")
    grant_permission!(@admin, "setup.bisac_subjects.import")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "bisacadmin", password: "Password123!" }
    @original_bisac_csv_path = ENV["BISAC_CSV_PATH"]
    ENV["BISAC_CSV_PATH"] = FIXTURE_PATH
    Bisac::CsvReader.send(:remove_const, :DEFAULT_PATH) if Bisac::CsvReader.const_defined?(:DEFAULT_PATH)
    Bisac::CsvReader.const_set(:DEFAULT_PATH, Pathname(FIXTURE_PATH).freeze)
  end

  teardown do
    if @original_bisac_csv_path
      ENV["BISAC_CSV_PATH"] = @original_bisac_csv_path
    else
      ENV.delete("BISAC_CSV_PATH")
    end
    Bisac::CsvReader.send(:remove_const, :DEFAULT_PATH) if Bisac::CsvReader.const_defined?(:DEFAULT_PATH)
    Bisac::CsvReader.const_set(:DEFAULT_PATH, Pathname(ENV.fetch("BISAC_CSV_PATH", Rails.root.join("db/seeds/data/bisac.csv"))).freeze)
  end

  test "show page loads for authorized user" do
    get setup_bisac_subjects_path

    assert_response :success
    assert_match "BISAC Subject Headings", response.body
  end

  test "import loads nodes and records audit event" do
    post import_setup_bisac_subjects_path

    assert_redirected_to setup_bisac_subjects_path
    assert CategoryScheme.exists?(scheme_key: "bisac")
    assert AuditEvent.exists?(event_name: "bisac_subjects.imported")
  end
end
