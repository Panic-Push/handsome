#!/usr/bin/env ruby
# Regenerates ios/Penwise.xcodeproj from the files on disk.
# Usage: ruby tools/generate_xcodeproj.rb   (needs: gem install xcodeproj)
require 'xcodeproj'
require 'fileutils'

ios_dir = File.expand_path('../ios', __dir__)
project_path = File.join(ios_dir, 'Penwise.xcodeproj')
FileUtils.rm_rf(project_path)
Dir.chdir(ios_dir)

# Write the project the way Xcode saves it, so opening it in Xcode changes
# nothing (and pulls never conflict): object version 54 (needed for Swift
# packages), and no group "name" when it equals the folder path.
project = Xcodeproj::Project.new(project_path, false, 54)
target = project.new_target(:application, 'Penwise', :ios, '17.0')

# Build the shared Kotlin engine (core/) into PenwiseCore.framework before
# Swift compiles, so `import PenwiseCore` always sees the latest engine.
kotlin = target.new_shell_script_build_phase('Build shared engine (Kotlin)')
kotlin.shell_path = '/bin/sh'
kotlin.always_out_of_date = '1'
kotlin.shell_script = <<~'SH'
  set -e
  if [ -z "$JAVA_HOME" ]; then
    JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
    export JAVA_HOME
  fi
  if [ -z "$JAVA_HOME" ]; then
    echo "error: Java was not found. Install a JDK (17 or newer): see README, Milestone 3."
    exit 1
  fi
  cd "$SRCROOT/.."
  ./gradlew :core:embedAndSignAppleFrameworkForXcode
SH
target.build_phases.delete(kotlin)
target.build_phases.unshift(kotlin)

# Swift packages: Lottie (animations), Google Mobile Ads and its consent
# library (User Messaging Platform). Versions are pinned exactly.
def add_package(project, target, url, version, products)
  package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package.repositoryURL = url
  package.requirement = { 'kind' => 'exactVersion', 'version' => version }
  project.root_object.package_references << package
  products.each do |name|
    product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    product.package = package
    product.product_name = name
    target.package_product_dependencies << product
    link = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    link.product_ref = product
    target.frameworks_build_phase.files << link
  end
end

add_package(project, target, 'https://github.com/airbnb/lottie-ios.git', '4.5.2', ['Lottie'])
add_package(project, target, 'https://github.com/googleads/swift-package-manager-google-mobile-ads.git',
            '13.13.0', ['GoogleMobileAds'])
add_package(project, target, 'https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git',
            '3.1.0', ['GoogleUserMessagingPlatform'])

# Source files and assets, mirroring the folder structure as groups.
app_group = project.main_group.new_group('Penwise', 'Penwise')
Dir.glob('Penwise/**/*').sort.each do |path|
  next if File.directory?(path) && !path.end_with?('.xcassets')
  next if path.include?('.xcassets/')
  relative = path.sub(%r{\APenwise/}, '')
  parts = File.dirname(relative).split('/').reject { |p| p == '.' }
  group = parts.inject(app_group) { |g, name| g[name] || g.new_group(name, name) }
  ref = group.new_reference(File.basename(path))
  if path.end_with?('.swift')
    target.source_build_phase.add_file_reference(ref)
  elsif path.end_with?('.xcassets') || path.end_with?('.xcprivacy')
    target.resources_build_phase.add_file_reference(ref)
  end
end

# Letter templates and journeys from /content, copied into the app as folders.
content_group = project.main_group.new_group('Content', '../content')
templates = content_group.new_reference('templates')
templates.last_known_file_type = 'folder'
target.resources_build_phase.add_file_reference(templates)
%w[journeys words].each do |folder|
  ref = content_group.new_reference(folder)
  ref.last_known_file_type = 'folder'
  target.resources_build_phase.add_file_reference(ref)
end

config_group = project.main_group.new_group('Config', 'Config')
config_group.new_reference('Info.plist')
config_group.new_reference('Penwise.entitlements')
# Local StoreKit catalogue: purchases work in Xcode before App Store Connect.
config_group.new_reference('Penwise.storekit')
# Signing settings come from Config/Base.xcconfig, which reads the personal,
# uncommitted Config/Local.xcconfig. Keeping them out of project.pbxproj means
# choosing a signing team never makes that file differ from the repository.
base_config = config_group.new_reference('Base.xcconfig')

target.build_configurations.each do |config|
  config.base_configuration_reference = base_config
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['MARKETING_VERSION'] = '0.1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['CODE_SIGN_ENTITLEMENTS'] = 'Config/Penwise.entitlements'
  s['INFOPLIST_FILE'] = 'Config/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = 'Penwise'
  s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  s['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad'] =
    'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown ' \
    'UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  s['TARGETED_DEVICE_FAMILY'] = '2' # iPad only
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['SUPPORTS_MACCATALYST'] = 'NO'
  s['SWIFT_VERSION'] = '5.0'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['ENABLE_PREVIEWS'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  # Shared engine produced by the "Build shared engine (Kotlin)" phase.
  s['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', '$(SRCROOT)/../core/build/xcode-frameworks/$(CONFIGURATION)/$(SDK_NAME)']
  s['OTHER_LDFLAGS'] = ['$(inherited)', '-framework', 'PenwiseCore']
  # The Kotlin build writes outside the Xcode sandbox.
  s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

project.objects.select { |o| o.isa == 'PBXGroup' }.each do |group|
  group.name = nil if group.name && group.name == group.path
end

# IDs derived from file paths instead of random ones, so regenerating the
# project only changes the lines that really changed.
project.predictabilize_uuids
project.root_object.attributes['TargetAttributes'] = {
  target.uuid => { 'SystemCapabilities' => { 'com.apple.SignInWithApple' => { 'enabled' => 1 } } }
}

project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil, launch_target: true)
scheme.save_as(project_path, 'Penwise', true)

# Run from Xcode with the local StoreKit catalogue (Product > Scheme > Edit
# Scheme > Run > Options shows it). Path is relative to the .xcodeproj.
scheme_path = File.join(project_path, 'xcshareddata', 'xcschemes', 'Penwise.xcscheme')
xml = File.read(scheme_path)
unless xml.include?('StoreKitConfigurationFileReference')
  xml.sub!(%r{(<LaunchAction[^>]*>)}m) do
    "#{Regexp.last_match(1)}\n      <StoreKitConfigurationFileReference\n         identifier = \"../Config/Penwise.storekit\">\n      </StoreKitConfigurationFileReference>"
  end
  File.write(scheme_path, xml)
end

puts "Generated #{project_path}"
