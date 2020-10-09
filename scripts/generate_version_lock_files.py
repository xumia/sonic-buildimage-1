#!/usr/bin/python

import argparse
import os
import sys


DEFAULT_VERSION_PATH = 'files/build/versions/default'
VERSION_DEB_PREFERENCE = '01-versions-deb'
VERSION_PREFIX_DEB = 'versions-deb'
VERSION_PREFIX_PIP2 = 'versions-pip'
VERSION_PREFIX_PIP3 = 'versions-pip3'
VERSION_PREFIX_WGET = 'versions-wget'
VERSION_PREFIX_GIT = 'versions-git'
VERSION_PREFIXES_COMMON = [VERSION_PREFIX_PIP2, VERSION_PREFIX_PIP3, VERSION_PREFIX_WGET, VERSION_PREFIX_GIT]


class VersionManager:
    @classmethod
    def get_versions(cls, version_file):
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

    @classmethod
    def merge_versions(cls, versions, version_file):
        result = versions.copy()
        new_versions = cls.get_versions(version_file)
        for package in new_versions:
            result[package] = new_versions[package]
        return result

    @classmethod
    def merge_version_files(cls, default_version_path, merge_version_path, version_prefix, distro, arch):
        version_file_distro = version_prefix + '-' + distro
        version_file_arch = version_file_distro + '-' + arch
        version_files = [version_prefix, version_file_distro, version_file_arch]
        versions = {}
        for version_file in version_files:
            default_version_file = os.path.join(default_version_path, version_file)
            versions = cls.merge_versions(versions, default_version_file)

        for version_file in version_files:
            merge_version_file = os.path.join(merge_version_path, version_file)
            versions = cls.merge_versions(versions, merge_version_file)

        return versions

    @classmethod
    def generate_deb_version_lock_file(cls, target_version_file, default_version_path, merge_version_path, distro, arch, priority=999):
        versions = cls.merge_version_files(default_version_path, merge_version_path, VERSION_PREFIX_DEB, distro, arch)
        if not versions:
            return
        with open(target_version_file, 'w') as f:
            for package in versions:
                f.write('Package: {0}\nPin: version {1}\nPin-Priority: {2}\n\n'.format(package, versions[package], priority))

    @classmethod
    def generate_common_version_lock_file(cls, target_version_file, default_version_path, merge_version_path, version_prefix, distro, arch):
        versions = cls.merge_version_files(default_version_path, merge_version_path, version_prefix, distro, arch)
        if not versions:
            return
        with open(target_version_file, 'w') as f:
            for package in versions:
                f.write('{0}=={1}\n'.format(package, versions[package]))

    @classmethod
    def generate_all_common_version_lock_file(cls, target_path, default_version_path, merge_version_path, distro, arch):
        for version_prefix in VERSION_PREFIXES_COMMON:
            target_version_file = os.path.join(target_path, version_prefix)
            cls.generate_common_version_lock_file(target_version_file, default_version_path, merge_version_path, version_prefix, distro, arch)

    @classmethod
    def generate_all_version_lock_file(cls, target_path, default_version_path, merge_version_path, distro, arch, priority=999):
        target_version_deb_file = os.path.join(target_path, VERSION_DEB_PREFERENCE)
        cls.generate_deb_version_lock_file(target_version_deb_file, default_version_path, merge_version_path, distro, arch, priority)
        cls.generate_all_common_version_lock_file(target_path, default_version_path, merge_version_path, distro, arch)


def main(args):
    if not os.path.exists(args.target_path):
        os.makedirs(args.target_path)
    VersionManager.generate_all_version_lock_file(args.target_path, args.base_path, args.override_path, args.distribution, args.architecture, args.priority)

if __name__ == "__main__":
    script_path = os.path.dirname(sys.argv[0])
    root_path = os.path.dirname(script_path)
    default_version_path = os.path.join(root_path, DEFAULT_VERSION_PATH)

    parser = argparse.ArgumentParser(description = 'Generate Version Lock Files')
    parser.add_argument('-t', '--target_path', required=True, help='target path to generate the version lock files')
    parser.add_argument('-o', '--override_path', required=True, help='version path to override the default version files')
    parser.add_argument('-d', '--distribution', required=True, help="distribution")
    parser.add_argument('-a', '--architecture', required=True, help="architecture")
    parser.add_argument('-p', '--priority', default=999, help="priority of the debian apt preference")
    parser.add_argument('-b', '--base_path', default=default_version_path, help="base version path that contains the default version files")
    args = parser.parse_args()
    main(args)
