#!/usr/bin/env python3
import re
import sys
import os

PBXPROJ_PATH = "InventoryWatch.xcodeproj/project.pbxproj"

with open(PBXPROJ_PATH, "r", encoding="utf-8") as f:
    content = f.read()

# Generate deterministic IDs for iOS target objects
# Prefix: 46F19A
TARGET_ID = "46F19A012739DA7300C1BAC2"
CONFIG_LIST_ID = "46F19A022739DA7300C1BAC2"
DEBUG_CONFIG_ID = "46F19A032739DA7300C1BAC2"
RELEASE_CONFIG_ID = "46F19A042739DA7300C1BAC2"
SOURCES_BUILD_PHASE_ID = "46F19A052739DA7300C1BAC2"
FRAMEWORKS_BUILD_PHASE_ID = "46F19A062739DA7300C1BAC2"
RESOURCES_BUILD_PHASE_ID = "46F19A072739DA7300C1BAC2"
PRODUCT_REF_ID = "46F19A082739DA7300C1BAC2"
IOS_GROUP_ID = "46F19A092739DA7300C1BAC2"

# File references for iOS-specific files
IOS_FILES = [
    ("46F19A102739DA7300C1BAC2", "InventoryWatchiOSApp.swift", "sourcecode.swift"),
    ("46F19A112739DA7300C1BAC2", "IOSContentView.swift", "sourcecode.swift"),
    ("46F19A122739DA7300C1BAC2", "IOSSettingsView.swift", "sourcecode.swift"),
    ("46F19A132739DA7300C1BAC2", "IOSSearchEditView.swift", "sourcecode.swift"),
    ("46F19A142739DA7300C1BAC2", "BackgroundRefreshManager.swift", "sourcecode.swift"),
    ("46F19A152739DA7300C1BAC2", "Info.plist", "text.plist.xml"),
]

# Shared source files (exclude macOS-specific: InventoryWatchApp, ContentView, SettingsView)
MACOS_ONLY_SOURCES = {"InventoryWatchApp.swift", "ContentView.swift", "SettingsView.swift"}

# Extract existing Sources files from macOS target
mac_sources_match = re.search(r'386FDC4F2739DA7300C1BAC2 /\* Sources \*/ = \{.*?files = \((.*?)\);', content, re.DOTALL)
if not mac_sources_match:
    print("Could not find macOS sources phase")
    sys.exit(1)

mac_sources_raw = mac_sources_match.group(1)
shared_source_filerefs = []
for line in mac_sources_raw.splitlines():
    line = line.strip()
    if not line:
        continue
    m = re.search(r'/\*\s*(.*?)\.swift in Sources\s*\*/', line)
    if m:
        fname = m.group(1) + ".swift"
        if fname in MACOS_ONLY_SOURCES:
            continue
        bf_id = line.split()[0]
        pat = re.escape(bf_id) + r'.*?fileRef = ([0-9a-zA-Z]+)'
        bf_match = re.search(pat, content)
        if bf_match:
            fileref_id = bf_match.group(1)
            shared_source_filerefs.append((fileref_id, fname))

print(f"Found {len(shared_source_filerefs)} shared source files")

# Extract existing Resources files from macOS target
mac_resources_match = re.search(r'386FDC512739DA7300C1BAC2 /\* Resources \*/ = \{.*?files = \((.*?)\);', content, re.DOTALL)
if not mac_resources_match:
    print("Could not find macOS resources phase")
    sys.exit(1)

mac_resources_raw = mac_resources_match.group(1)
shared_resource_filerefs = []
for line in mac_resources_raw.splitlines():
    line = line.strip()
    if not line:
        continue
    m = re.search(r'/\*\s*(.*?)\s+in Resources\s*\*/', line)
    if m:
        rname = m.group(1)
        bf_id = line.split()[0]
        pat = re.escape(bf_id) + r'.*?fileRef = ([0-9a-zA-Z]+)'
        bf_match = re.search(pat, content)
        if bf_match:
            fileref_id = bf_match.group(1)
            shared_resource_filerefs.append((fileref_id, rname))

print(f"Found {len(shared_resource_filerefs)} shared resource files")

# Build new PBXBuildFile entries for iOS Sources
new_build_files = []
ios_sources_entries = []

# iOS-specific sources build files
for idx, (fref, fname, ftype) in enumerate(IOS_FILES):
    if ftype == "sourcecode.swift":
        bf_id = f"46F19A2{idx:01d}2739DA7300C1BAC2"
        new_build_files.append(f'\t\t{bf_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {fname} */; }};')
        ios_sources_entries.append(f'\t\t\t\t{bf_id} /* {fname} in Sources */,')

# Shared sources build files
for idx, (fref, fname) in enumerate(shared_source_filerefs):
    bf_id = f"46F19A3{idx:02X}2739DA7300C1BAC2"
    new_build_files.append(f'\t\t{bf_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {fname} */; }};')
    ios_sources_entries.append(f'\t\t\t\t{bf_id} /* {fname} in Sources */,')

# Shared resources build files
ios_resources_entries = []
for idx, (fref, rname) in enumerate(shared_resource_filerefs):
    bf_id = f"46F19A5{idx:02X}2739DA7300C1BAC2"
    new_build_files.append(f'\t\t{bf_id} /* {rname} in Resources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {rname} */; }};')
    ios_resources_entries.append(f'\t\t\t\t{bf_id} /* {rname} in Resources */,')

# Build new PBXFileReference entries
new_file_refs = []
for fref, fname, ftype in IOS_FILES:
    new_file_refs.append(f'\t\t{fref} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{fname}"; sourceTree = "<group>"; }};')

new_file_refs.append(f'\t\t{PRODUCT_REF_ID} /* InventoryWatch-iOS.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "InventoryWatch-iOS.app"; sourceTree = BUILT_PRODUCTS_DIR; }};')

# Insert PBXBuildFile entries
content = content.replace("/* Begin PBXBuildFile section */\n", "/* Begin PBXBuildFile section */\n" + "\n".join(new_build_files) + "\n")

# Insert PBXFileReference entries
content = content.replace("/* Begin PBXFileReference section */\n", "/* Begin PBXFileReference section */\n" + "\n".join(new_file_refs) + "\n")

# Insert PBXGroup for iOS files
ios_group_children = "\n".join([f'\t\t\t\t{fref} /* {fname} */,' for fref, fname, _ in IOS_FILES])
new_group = f"""\t\t{IOS_GROUP_ID} /* iOS */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{ios_group_children}
\t\t\t);
\t\t\tpath = iOS;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
content = content.replace("/* Begin PBXGroup section */\n", "/* Begin PBXGroup section */\n" + new_group)

# Add iOS group to InventoryWatch PBXGroup (386FDC552739DA7300C1BAC2)
content = content.replace(
    "386FDC552739DA7300C1BAC2 /* InventoryWatch */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n",
    f"386FDC552739DA7300C1BAC2 /* InventoryWatch */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{IOS_GROUP_ID} /* iOS */,\n"
)

# Add Product to Products group (386FDC542739DA7300C1BAC2)
content = content.replace(
    "386FDC542739DA7300C1BAC2 /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n",
    f"386FDC542739DA7300C1BAC2 /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{PRODUCT_REF_ID} /* InventoryWatch-iOS.app */,\n"
)

# Insert PBXFrameworksBuildPhase for iOS
frameworks_phase = f"""\t\t{FRAMEWORKS_BUILD_PHASE_ID} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
content = content.replace("/* Begin PBXFrameworksBuildPhase section */\n", "/* Begin PBXFrameworksBuildPhase section */\n" + frameworks_phase)

# Insert PBXResourcesBuildPhase for iOS
resources_phase = f"""\t\t{RESOURCES_BUILD_PHASE_ID} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(ios_resources_entries)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
content = content.replace("/* Begin PBXResourcesBuildPhase section */\n", "/* Begin PBXResourcesBuildPhase section */\n" + resources_phase)

# Insert PBXSourcesBuildPhase for iOS
sources_phase = f"""\t\t{SOURCES_BUILD_PHASE_ID} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(ios_sources_entries)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
content = content.replace("/* Begin PBXSourcesBuildPhase section */\n", "/* Begin PBXSourcesBuildPhase section */\n" + sources_phase)

# Insert PBXNativeTarget for iOS
ios_target = f"""\t\t{TARGET_ID} /* InventoryWatch-iOS */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget "InventoryWatch-iOS" */;
\t\t\tbuildPhases = (
\t\t\t\t{SOURCES_BUILD_PHASE_ID} /* Sources */,
\t\t\t\t{FRAMEWORKS_BUILD_PHASE_ID} /* Frameworks */,
\t\t\t\t{RESOURCES_BUILD_PHASE_ID} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = "InventoryWatch-iOS";
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = InventoryWatch;
\t\t\tproductReference = {PRODUCT_REF_ID} /* InventoryWatch-iOS.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""
content = content.replace("/* Begin PBXNativeTarget section */\n", "/* Begin PBXNativeTarget section */\n" + ios_target)

# Add target to PBXProject
content = content.replace(
    "386FDC4B2739DA7300C1BAC2 /* Project object */ = {\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 2700;\n\t\t\t\tLastUpgradeCheck = 2700;\n\t\t\t\tTargetAttributes = {\n",
    f"386FDC4B2739DA7300C1BAC2 /* Project object */ = {{\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {{\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 2700;\n\t\t\t\tLastUpgradeCheck = 2700;\n\t\t\t\tTargetAttributes = {{\n\t\t\t\t\t{TARGET_ID} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t}};\n"
)

content = content.replace(
    "targets = (\n\t\t\t\t386FDC522739DA7300C1BAC2 /* InventoryWatch */,\n\t\t\t\t46F11C57304B78510000EBF2 /* InventoryWatchTests */,\n\t\t\t);",
    f"targets = (\n\t\t\t\t386FDC522739DA7300C1BAC2 /* InventoryWatch */,\n\t\t\t\t46F11C57304B78510000EBF2 /* InventoryWatchTests */,\n\t\t\t\t{TARGET_ID} /* InventoryWatch-iOS */,\n\t\t\t);"
)

# XCBuildConfiguration for iOS
debug_ios_config = f"""\t\t{DEBUG_CONFIG_ID} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"InventoryWatch/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = InventoryWatch/iOS/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = "3.0.0-RC.2";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = net.brendamour.InventoryWatch.ios;
\t\t\t\tPRODUCT_NAME = InventoryWatch;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""

release_ios_config = f"""\t\t{RELEASE_CONFIG_ID} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"InventoryWatch/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = InventoryWatch/iOS/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = "3.0.0-RC.2";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = net.brendamour.InventoryWatch.ios;
\t\t\t\tPRODUCT_NAME = InventoryWatch;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""

content = content.replace("/* Begin XCBuildConfiguration section */\n", "/* Begin XCBuildConfiguration section */\n" + debug_ios_config + release_ios_config)

# XCConfigurationList for iOS
config_list = f"""\t\t{CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget "InventoryWatch-iOS" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{DEBUG_CONFIG_ID} /* Debug */,
\t\t\t\t{RELEASE_CONFIG_ID} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""
content = content.replace("/* Begin XCConfigurationList section */\n", "/* Begin XCConfigurationList section */\n" + config_list)

with open(PBXPROJ_PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated project.pbxproj successfully!")

# Now create the scheme for iOS
SCHEME_DIR = "InventoryWatch.xcodeproj/xcshareddata/xcschemes"
os.makedirs(SCHEME_DIR, exist_ok=True)
SCHEME_PATH = os.path.join(SCHEME_DIR, "InventoryWatch-iOS.xcscheme")

scheme_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2700"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{TARGET_ID}"
               BuildableName = "InventoryWatch.app"
               BlueprintName = "InventoryWatch-iOS"
               ReferencedContainer = "container:InventoryWatch.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{TARGET_ID}"
            BuildableName = "InventoryWatch.app"
            BlueprintName = "InventoryWatch-iOS"
            ReferencedContainer = "container:InventoryWatch.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{TARGET_ID}"
            BuildableName = "InventoryWatch.app"
            BlueprintName = "InventoryWatch-iOS"
            ReferencedContainer = "container:InventoryWatch.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

with open(SCHEME_PATH, "w", encoding="utf-8") as f:
    f.write(scheme_content)

print(f"Created scheme {SCHEME_PATH} successfully!")
