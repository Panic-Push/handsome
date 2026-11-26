#!/usr/bin/env ruby
# Regenerates ios/Penwise.xcodeproj from the files on disk.
# Usage: ruby tools/generate_xcodeproj.rb   (needs: gem install xcodeproj)
require 'xcodeproj'
require 'fileutils'

ios_dir = File.expand_path('../ios', __dir__)
project_path = File.join(ios_dir, 'Penwise.xcodeproj')
FileUtils.rm_rf(project_path)
Dir.chdir(ios_dir)

project = Xcodeproj::Project.new(project_path)
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

package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
package.repositoryURL = 'https://github.com/airbnb/lottie-ios.git'
package.requirement = { 'kind' => 'exactVersion', 'version' => '4.5.2' }
project.root_object.package_references << package
product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = package
product.product_name = 'Lottie'
target.package_product_dependencies << product
link = project.new(Xcodeproj::Project::Object::PBXBuildFile)
link.product_ref = product
target.frameworks_build_phase.files << link

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
  elsif path.end_with?('.xcassets')
    target.resources_build_phase.add_file_reference(ref)
  end
end

# Letter templates and journeys from /content, copied into the app as folders.
content_group = project.main_group.new_group('Content', '../content')
templates = content_group.new_reference('templates')
templates.last_known_file_type = 'folder'
target.resources_build_phase.add_file_reference(templates)
journeys = content_group.new_reference('journeys')
journeys.last_known_file_type = 'folder'
target.resources_build_phase.add_file_reference(journeys)

config_group = project.main_group.new_group('Config', 'Config')
config_group.new_reference('Info.plist')

target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.penwise.dev'
  s['MARKETING_VERSION'] = '0.1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
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
  s['DEVELOPMENT_TEAM'] = ''
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

project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil, launch_target: true)
scheme.save_as(project_path, 'Penwise', true)

puts "Generated #{project_path}"
