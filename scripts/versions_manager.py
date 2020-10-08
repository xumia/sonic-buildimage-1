#!/usr/bin/python3

import argparse
import glob
import os
import sys


DEFAULT_VERSION_PATH = 'files/build/versions'
VERSION_DEB_PREFERENCE = '01-versions-deb'
VERSION_PREFIX="versions-"
PACKAGE_DEBIAN = 'deb'
VERSION_TYPES = [ 'deb', 'py2', 'py3', 'wget', 'git' ]
VERSION_PREFIX_DEB = 'versions-deb'
VERSION_PREFIX_PY2 = 'versions-py2'
VERSION_PREFIX_PY3 = 'versions-py3'
VERSION_PREFIX_WGET = 'versions-wget'
VERSION_PREFIX_GIT = 'versions-git'
VERSION_PREFIXES_COMMON = [VERSION_PREFIX_PY2, VERSION_PREFIX_PY3, VERSION_PREFIX_WGET, VERSION_PREFIX_GIT]


class Component:
    '''
    The component consists of mutiple packages

    ctype -- Component Type, such as deb, py2, etc
    dist  -- Distribution, such as stretch, buster, etc
    arch  -- Architectrue, such as amd64, arm64, etc
    
    '''
    def __init__(self, versions, ctype, dist, arch):
        self.versions = versions
        self.ctype = ctype
        self.dist = dist
        self.arch = arch

    @classmethod
    def get_versions(cls, version_file):
        version = {}
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

    def clone(self):
        return PackageVersions(self.versions.copy(), self.ctype, self.dist, self.arch)

    def merge(self, package_versions):
        for package in package_versions.versions:
            self.versions[package] = package_versions.versions[package]

    def dump(self):
        result = []
        for package in sorted(self.versions.keys()):
            result.append('{0}=={1}'.format(package, self.versions[package]))
        return "\n".join(result)

    def dump_to_file(self, version_file):
        with open(version_file, 'w') as f:
            f.writ(self.dump())


class VersionModule:
    '''
    The version module represents a build target, such as docker image, host image, consists of multiple components.

    name   -- The name of the image, such as sonic-slave-buster, docker-lldp, etc
    '''
    def __init__(self, name, components):
        self.name = name
        self.components = components

    def inherit(self, base_image):
        pass

    def merge(self, base_image):
        pass

    def subtract(self, base_image):
        for base_component in base_image.components:
            for component in self.components:
                if base_component.ctype != component.ctype:
                    continue
                if 

    def load(self, image_path, filter_ctype=None, filter_dist=None, filter_arch=None):
        version_file_pattern = os.path.join(image_path, VERSION_PREFIX) + '*'
        file_path = glob.glob(version_file_pattern)
        components = []
        self.name = os.path.basename(image_path)
        self.components = components
        for file_path in file_paths:
            filename = os.path.basename(file_path)
            items = filename.split('-')
            if len(items) < 2:
                continue
            ctype = items[1]
            if filter_ctype and filter_ctype != ctype:
                continue
            dist = ''
            arch = ''
            if len(items) > 2:
                dist = items[2]
            if filter_dist and dist and filter_dist != dist:
                continue
            if len(items) > 3:
                arch = items[3]
            if filter_arch and arch and filter_arch != arch:
                continue
            versions = Component.get_versions()
            component = Component(versions, ctype, dist, arch)
            components.append(component)

    def load_from_build_result(self, image_path):
        self.load(image_path)
        arch = self._get_dist(image_path)
        dist = self._get_dist(image_path)
        for component in self.components:
            if arch:
                component.arch = arch
            if dist:
                component.dist = dist

    def _get_dist(self, image_path):
        dist = ''
        os_release = os.path.join(image_path, 'os_release')
        if not os.path.exists(os_release):
            return dist
        with open(os_release, 'r') as f:
            lines=f.readlines()
            for line in lines:
                line = line.strip()
                items = line.split('=')
                if len(items) != 2:
                    continue
                if items[0] == 'VERSION_CODENAME':
                    dist = items[1].strip()
                if not dist and 'jessie' in line:
                    dist = 'jessie'
        return dist

    def _get_arch(self):
        arch = ''
        arch_path = '.arch'
        if not os.path.exists(arch_path):
            return arch
        with open(arch_path, 'r') as f:
            lines=f.readlines()
            if len(lines) > 0:
                arch = lines[0].strip()
        return arch

class Build:
    '''
    The Build consists of multiple version modules.

    self.name        The name of the image, such as sonic-slave-buster, docker-lldp, etc
    '''
    def __init__(self, target_path="./target", source_path='.'):
        self.target_path = target_path
        self.source_path = source_path
        self.modules = {}

    def load_from_target(self):
        dockers_path = os.path.join(self.target_path, 'versions/dockers')
        modules = {}
        self.modules = modules
        for file_path in os.walk(dockers_path):
            module = load_from_build_result(self, file_path)
            modules[module.name] = module

    def load_from_source(self):
        pass

    def merge(self, build):
        pass

    def freeze(self):
        pass

    def get_base_image(self):
        pass

    def get_docker_version_modules(self):
        pass


'''
Version Freezer

Freeze the versions after a build. It is used to freeze the versions of python packages,
debian packages, and the package downloaded from web, etc.
'''
class VersionFreezer:
    def __init__(self, versions):
        self.versions = versions
        self.arch = arch
        self


    def freeze(self, distro, arch):
        pass

class VersionGenerator:
    pass

class VersionManager2:
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


class VersionManagerCommands:
    def __init__(self):
        usage = 'version_manager <command> [<args>]\n\n'
        usage = usage + 'The most commonly used commands are:\n'
        usage = usage + '   generate   Generate the version files\n'
        usage = usage + '   freeze     Freeze the version files'
        parser = argparse.ArgumentParser(description='Version manager', usage=usage)
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(sys.argv[1:2])
        if not hasattr(self, args.command):
            print 'Unrecognized command'
            parser.print_help()
            exit(1)
        getattr(self, args.command)()

    def generate(self):
        script_path = os.path.dirname(sys.argv[0])
        root_path = os.path.dirname(script_path)
        default_version_path = os.path.join(root_path, DEFAULT_VERSION_PATH)

        parser = argparse.ArgumentParser(description = 'Generate the version files')
        parser.add_argument('-t', '--target_path', required=True, help='target path to generate the version lock files')
        parser.add_argument('-o', '--override_path', required=True, help='version path to override the default version files')
        parser.add_argument('-d', '--distribution', required=True, help="distribution")
        parser.add_argument('-a', '--architecture', required=True, help="architecture")
        parser.add_argument('-p', '--priority', default=999, help="priority of the debian apt preference")
        parser.add_argument('-b', '--base_path', default=default_version_path, help="base version path that contains the default version files")
        args = parser.parse_args(sys.argv[2:])
        if not os.path.exists(args.target_path):
            os.makedirs(args.target_path)
        VersionManager.generate_all_version_lock_file(args.target_path, args.base_path, args.override_path, args.distribution, args.architecture, args.priority)

    def freeze(self):
        parser = argparse.ArgumentParser(description = 'Freeze the version files')

def main(args):
    if not os.path.exists(args.target_path):
        os.makedirs(args.target_path)
    VersionManager.generate_all_version_lock_file(args.target_path, args.base_path, args.override_path, args.distribution, args.architecture, args.priority)

if __name__ == "__main__":
    VersionManagerCommands()
