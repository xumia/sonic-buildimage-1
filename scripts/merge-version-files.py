#!/usr/bin/python

import os
import sys

DEFAULT_VERSION_PATH = 'files/build/versions'

def get_versions(version_file):
    result = {}
    if not os.path.exists(version_file):
        return result
    with open(version_file) as fp:
        for line in fp.readlines():
            offset = line.rfind('==')
            if offset > 0:
                package = line[:offset].strip()
                version = line[offset+2:].strip()
                result[package] = version
    return result

def merge_versions(version_file, versions):
    result = versions.copy()
    override_versions = get_versions(version_file)
    for package in override_versions:
        result[package] = override_versions[package]
    return result

def generate_versions_file(file_path, versions):
    with open(file_path, 'w') as fp:
        for package in sorted(versions.keys(), key=lambda s: s.lower()):
            fp.write('{0}=={1}\n'.format(package, versions[package]))

def merge_versions_file(distro, version_dir, version_file_name):
    default_version_file = os.path.join(DEFAULT_VERSION_PATH, version_file_name)
    target_version_file = os.path.join(version_dir, version_file_name)
    merge_files = [
        default_version_file + "-" + distro,
        target_version_file,
        target_version_file + "-" + distro,
    ]
    versions = get_versions(default_version_file)
    for merge_file in merge_files:
        versions = merge_versions(merge_file, versions)
    return versions

def merge_and_generate_versions_file(distro, version_dir, target_dir):
    version_file_names = ['versions-deb', 'versions-py2', 'versions-py3', 'versions-web']
    for version_file_name in version_file_names:
        versions = merge_versions_file(distro, version_dir, version_file_name)
        file_path = os.path.join(target_dir, version_file_name)
        generate_versions_file(file_path, versions)

def main():
    distro = sys.argv[1]
    version_dir = sys.argv[2]
    target_dir = sys.argv[3]
    merge_and_generate_versions_file(distro, version_dir, target_dir)

if __name__ == "__main__":
    main()

