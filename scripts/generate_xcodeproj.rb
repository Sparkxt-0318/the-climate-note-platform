require "xcodeproj"
require "fileutils"
require "pathname"

root = File.expand_path("..", __dir__)
ios_root = File.join(root, "apps", "ios")
project_path = File.join(ios_root, "ClimateNote.xcodeproj")
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes["LastSwiftUpdateCheck"] = "2660"
project.root_object.attributes["LastUpgradeCheck"] = "2660"

app_target = project.new_target(:application, "ClimateNote", :ios, "17.0")
test_target = project.new_target(:unit_test_bundle, "ClimateNoteTests", :ios, "17.0")
test_target.add_dependency(app_target)

app_group = project.main_group.new_group("ClimateNote", "ClimateNote")
test_group = project.main_group.new_group("ClimateNoteTests", "ClimateNoteTests")

source_refs = Dir.glob(File.join(ios_root, "ClimateNote", "**", "*.swift")).sort.map do |path|
  app_group.new_file(Pathname.new(path).relative_path_from(Pathname.new(File.join(ios_root, "ClimateNote"))).to_s)
end
test_refs = Dir.glob(File.join(ios_root, "ClimateNoteTests", "**", "*.swift")).sort.map do |path|
  test_group.new_file(Pathname.new(path).relative_path_from(Pathname.new(File.join(ios_root, "ClimateNoteTests"))).to_s)
end
resource_paths = ["Resources/Assets.xcassets", "Support/PrivacyInfo.xcprivacy"]
google_service_path = File.join(ios_root, "ClimateNote", "Support", "GoogleService-Info.plist")
resource_paths << "Support/GoogleService-Info.plist" if File.exist?(google_service_path)
resource_refs = resource_paths.map { |path| app_group.new_file(path) }

app_target.add_file_references(source_refs)
test_target.add_file_references(test_refs)
resource_refs.each { |ref| app_target.resources_build_phase.add_file_reference(ref) }

def add_remote_package(project, repository_url, minimum_version)
  package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package.repositoryURL = repository_url
  package.requirement = {
    "kind" => "upToNextMajorVersion",
    "minimumVersion" => minimum_version
  }
  project.root_object.package_references << package
  package
end

def add_package_product(project, target, package, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package
  dependency.product_name = product_name
  target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

firebase_package = add_remote_package(
  project,
  "https://github.com/firebase/firebase-ios-sdk.git",
  "12.18.0"
)
%w[FirebaseCore FirebaseAuth FirebaseFirestore FirebaseMessaging].each do |product_name|
  add_package_product(project, app_target, firebase_package, product_name)
end

google_sign_in_package = add_remote_package(
  project,
  "https://github.com/google/GoogleSignIn-iOS.git",
  "9.2.0"
)
add_package_product(project, app_target, google_sign_in_package, "GoogleSignIn")

reversed_client_id = "com.googleusercontent.apps.pending-firebase-configuration"
if File.exist?(google_service_path)
  google_configuration = Xcodeproj::Plist.read_from_path(google_service_path)
  reversed_client_id = google_configuration["REVERSED_CLIENT_ID"] || reversed_client_id
end

app_target.build_configurations.each do |config|
  push_environment = config.name == "Release" ? "production" : "development"
  settings = {
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.theclimatenote.app",
    "PRODUCT_NAME" => "The Climate Note",
    "PRODUCT_MODULE_NAME" => "ClimateNote",
    "INFOPLIST_FILE" => "ClimateNote/Support/Info.plist",
    "CODE_SIGN_ENTITLEMENTS" => "ClimateNote/Support/ClimateNote.entitlements",
    "CODE_SIGN_STYLE" => config.name == "Release" ? "Manual" : "Automatic",
    "CURRENT_PROJECT_VERSION" => "2",
    "CLIMATE_NOTE_API_BASE_URL" => "https://the-climate-note.vercel.app",
    "REVERSED_CLIENT_ID" => reversed_client_id,
    "APS_ENVIRONMENT" => push_environment,
    "DEVELOPMENT_TEAM" => "F8X3YXYMWH",
    "MARKETING_VERSION" => "1.0.0",
    "OTHER_LDFLAGS" => "$(inherited) -ObjC -lc++",
    "SWIFT_VERSION" => "6.0",
    "SWIFT_STRICT_CONCURRENCY" => "complete",
    "TARGETED_DEVICE_FAMILY" => "1",
    "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
    "ENABLE_USER_SCRIPT_SANDBOXING" => "YES"
  }
  if config.name == "Release"
    settings["CODE_SIGN_IDENTITY"] = "Apple Distribution"
    settings["PROVISIONING_PROFILE_SPECIFIER"] = "The Climate Note App Store 2026"
  end
  config.build_settings.merge!(settings)
end

test_target.build_configurations.each do |config|
  config.build_settings.merge!({
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.theclimatenote.app.tests",
    "GENERATE_INFOPLIST_FILE" => "YES",
    "SWIFT_VERSION" => "6.0",
    "SWIFT_STRICT_CONCURRENCY" => "complete",
    "TEST_HOST" => "$(BUILT_PRODUCTS_DIR)/The Climate Note.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/The Climate Note",
    "BUNDLE_LOADER" => "$(TEST_HOST)"
  })
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.set_launch_target(app_target)
scheme.add_test_target(test_target)
scheme.save_as(project_path, "ClimateNote", true)

puts project_path
