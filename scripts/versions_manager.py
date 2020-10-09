#!/usr/bin/python3

import argparse
import glob
import os
import sys


COMMON_MODULE = 'default'
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
ALL_DIST = 'all'
ALL_ARCH = 'all'


class Component:
    '''
    The component consists of mutiple packages

    ctype -- Component Type, such as deb, py2, etc
    dist  -- Distribution, such as stretch, buster, etc
    arch  -- Architectrue, such as amd64, arm64, etc
    
    '''
    def __init__(self, versions, ctype, dist=None, arch=None):
        self.versions = versions
        self.ctype = ctype
        self.dist = dist
        self.arch = arch

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

    def clone(self):
        return PackageVersions(self.versions.copy(), self.ctype, self.dist, self.arch)

    def merge(self, package_versions):
        for package in package_versions.versions:
            self.versions[package] = package_versions.versions[package]

    def dump(self):
        result = []
        for package in sorted(self.versions.keys(), key=str.casefold):
            result.append('{0}=={1}'.format(package, self.versions[package]))
        return "\n".join(result)

    def dump_to_file(self, version_file):
        if len(self.versions) <= 0:
            return
        with open(version_file, 'w') as f:
            f.write(self.dump())

    def dump_to_path(self, file_path):
        filename = self.get_filename()
        file_path = os.path.join(file_path, filename)
        self.dump_to_file(file_path)

    '''
    Get the file name

    The file name format: versions-{ctype}-{dist}-{arch}
    If {arch} is all, then the file name format: versions-{ctype}-{dist}
    if {arch} is all and {dist} is all, then the file name format: versions-{ctype}
    '''
    def get_filename(self):
        filename = VERSION_PREFIX + self.ctype
        dist = self.dist
        if self.arch and self.arch != ALL_ARCH:
            if not dist:
                dist = ALL_DIST
            return filename + '-' + dist + '-' + self.arch
        if dist and self.dist != ALL_DIST:
            filename = filename + '-' + dist
        return filename


class VersionModule:
    '''
    The version module represents a build target, such as docker image, host image, consists of multiple components.

    name   -- The name of the image, such as sonic-slave-buster, docker-lldp, etc
    '''
    def __init__(self, name=None, components=None):
        self.name = name
        self.components = components

    def inherit(self, base_image):
        pass

    def merge(self, base_image):
        pass

    def subtract(self, base_module):
        for component in self.components:
            for base_component in base_module.components:
                if component.ctype != base_component.ctype:
                    continue
                versions = {}
                for package in component.versions:
                    version = component.versions[package]
                    if package not in base_component.versions or version !=  base_component.versions[package]:
                        versions[package] = version
                component.versions = versions


    def load(self, image_path, filter_ctype=None, filter_dist=None, filter_arch=None):
        version_file_pattern = os.path.join(image_path, VERSION_PREFIX) + '*'
        file_paths = glob.glob(version_file_pattern)
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
            versions = Component.get_versions(file_path)
            component = Component(versions, ctype, dist, arch)
            components.append(component)

    def load_from_target(self, image_path):
        self.load(image_path)
        arch = self._get_arch()
        dist = self._get_dist(image_path)
        for component in self.components:
            if arch:
                component.arch = arch
            if dist:
                component.dist = dist

    def dump(self, module_path):
        version_file_pattern = os.path.join(module_path, VERSION_PREFIX + '*')
        for filename in glob.glob(version_file_pattern):
            os.remove(filename)
        for component in self.components:
            component.dump_to_path(module_path)

    def _get_dist(self, image_path):
        dist = ''
        os_release = os.path.join(image_path, 'os-release')
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

    '''
    def __init__(self, target_path="./target", source_path='.'):
        self.target_path = target_path
        self.source_path = source_path
        self.modules = {}

    def load_from_target(self):
        dockers_path = os.path.join(self.target_path, 'versions/dockers')
        modules = {}
        self.modules = modules
        file_paths = glob.glob(dockers_path + '/*')
        file_paths.append(os.path.join(self.target_path, 'versions/host-image'))
        file_paths.append(os.path.join(self.target_path, 'versions/host-base-image'))
        for file_path in file_paths:
            if not os.path.isdir(file_path):
                continue
            module = VersionModule()
            module.load_from_target(file_path)
            modules[module.name] = module
        self._merge_dgb_modules()

    def load_from_source(self):
        # Load dockers
        docker_pattern = os.path.join(self.source_path, 'dockers/*/versions-*')
        paths = self._get_module_paths_by_pattern(docker_pattern)
        slave_docker_pattern = os.path.join(self.source_path, 'sonic-slave-*/versions-*')
        paths = paths + self._get_module_paths_by_pattern(slave_docker_pattern)
        platform_docker_pattern = os.path.join(self.source_path, 'platform/*/*/versions-*')
        paths = paths + self._get_module_paths_by_pattern(platform_docker_pattern)

        # Load default versions and host image versions
        other_pattern = os.path.join(self.source_path, 'files/build/versions/*/versions-*')
        paths = paths + self._get_module_paths_by_pattern(other_pattern)
        modules = {}
        self.modules = modules
        for image_path in paths:
            module = VersionModule()
            module.load(image_path)
            modules[module.name] = module

    def merge(self, build):
        pass

    def freeze(self):
        common_module = self.get_common_module()
        self._clean_component_info()
        for module in self.modules.values():
            if module.name == COMMON_MODULE:
                continue
            if module.name != 'host-base-image':
                module.subtract(common_module)
            module_path = self.get_module_path(module)
            module.dump(module_path)
        common_module_path = os.path.join(self.source_path, "files/build/versions/default")
        common_module.dump(common_module_path)

    def get_common_module(self):
        ctypes = self.get_component_types()
        dists = self.get_dists()
        components = []
        for ctype in ctypes:
            if ctype == 'deb':
                for dist in dists:
                    versions = self._get_versions(ctype, dist)
                    common_versions = self._get_common_versions(versions)
                    component = Component(common_versions, ctype, dist)
                    components.append(component)
            else:
                versions = self._get_versions(ctype)
                common_versions = self._get_common_versions(versions)
                component = Component(common_versions, ctype)
                components.append(component)
        return VersionModule(COMMON_MODULE, components)

    def get_docker_version_modules(self):
        modules = []
        for module_name in self.modules:
            if module_name.startswith('sonic-slave-'):
                continue
            if module_name == COMMON_MODULE:
                continue
            if module_name == 'host-image' or module_name == 'host-base-image':
                continue
            module = self.modules[module_name]
            modules.append(module)
        return modules

    def get_components(self):
        components = []
        for module_name in self.modules:
            module = self.modules[module_name]
            for component in module.components:
                components.append(component)
        return components

    def get_component_types(self):
        ctypes = []
        for module_name in self.modules:
            module = self.modules[module_name]
            for component in module.components:
               if component.ctype not in ctypes:
                   ctypes.append(component.ctype)
        return ctypes

    def get_dists(self):
        dists = []
        components = self.get_components()
        for component in components:
            if component.dist not in dists:
                dists.append(component.dist)
        return dists

    def get_archs(self):
        archs = []
        components = self.get_components()
        for component in components:
            if component.arch not in archs:
                archs.append(component.arch)
        return archs

    def get_module_path(self, module):
        common_modules = ['default', 'host-image', 'host-base-image']
        if module.name in common_modules:
            return os.path.join(self.source_path, 'files/build/versions', module.name)
        if module.name.startswith('sonic-slave-'):
            return os.path.join(self.source_path, module.name)
        file_path = os.path.join(self.source_path, 'dockers', module.name)
        if os.path.exists(file_path):
            return file_path
        file_path = os.path.join(self.source_path, 'platform', '*', module.name)
        files = glob.glob(file_path)
        if len(files) == 1:
            return files[0]
        raise Exception('The path of module name {0} not found'.format(module.name))

    def _get_module_paths_by_pattern(self, pattern):
        files = glob.glob(pattern)
        paths = []
        for file_path in files:
            parent = os.path.dirname(file_path)
            if parent not in paths:
                paths.append(parent)
        return paths

    def _merge_dgb_modules(self):
        dbg_modules = []
        for module_name in self.modules:
            if not module_name.endswith('-dbg'):
                continue
            dbg_modules.append(module_name)
            base_module_name = module_name[:-4]
            if base_module_name not in self.modules:
                raise Exception('The Module {0} not found'.format(base_module_name))
            base_module = self.modules[base_module_name]
            dbg_module = self.modules[module_name]
            for dbg_component in dbg_module.components:
                found_component = None
                for component in base_module.components:
                    if component.ctype == dbg_component.ctype:
                        found_component = component
                if not found_component:
                    base_module.components.append(dbg_component)
                else:
                    base_module.merge(dbg_component)
        for module_name in dbg_modules:
            del self.modules[module_name]

    def _clean_component_info(self, clean_dist=True, clean_arch=True):
        for module in self.modules.values():
            for component in module.components:
                if clean_dist:
                    component.dist = None
                if clean_arch:
                    component.arch = None

    def _get_versions(self, ctype, dist=None, arch=None):
        versions = {}
        modules = self.get_docker_version_modules()
        for module in modules:
            for component in module.components:
                if ctype != component.ctype:
                    continue
                if dist and dist != component.dist:
                    continue
                if arch and arch != component.arch:
                    continue
                for package in component.versions:
                    version = component.versions[package]
                    package_versions = versions.get(package, [])
                    if version not in package_versions:
                        package_versions.append(version)
                    versions[package] = package_versions
        return versions

    def _get_common_versions(self, versions):
        common_versions = {}
        for package in versions:
            package_versions = versions[package]
            if len(package_versions) == 1:
                common_versions[package] = package_versions[0]
        return common_versions


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
            print('Unrecognized command')
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
        build = Build()
        build.load_from_target()
        versions = build._get_versions('deb', dist='buster')
        dists = build.get_dists()
        archs = build.get_archs()
        common_versions = build._get_common_versions(versions)
        nono_common_versions = {}
        common_module = build.get_common_module()
        build.freeze()
        build2 = Build()
        build2.load_from_source()
        for package in versions:
            if package not in common_versions:
                nono_common_versions[package] = versions[package]
        import pdb; pdb.set_trace()

def main(args):
    if not os.path.exists(args.target_path):
        os.makedirs(args.target_path)
    VersionManager.generate_all_version_lock_file(args.target_path, args.base_path, args.override_path, args.distribution, args.architecture, args.priority)

if __name__ == "__main__":
    VersionManagerCommands()
