#!/usr/bin/python3

import argparse
import glob
import os
import sys


DEFAULT_MODULE = 'default'
DEFAULT_VERSION_PATH = 'files/build/versions'
VERSION_DEB_PREFERENCE = '01-versions-deb'
VERSION_PREFIX="versions-"
ALL_DIST = 'all'
ALL_ARCH = 'all'


class Component:
    '''
    The component consists of mutiple packages

    ctype -- Component Type, such as deb, py2, etc
    dist  -- Distribution, such as stretch, buster, etc
    arch  -- Architectrue, such as amd64, arm64, etc
    
    '''
    def __init__(self, versions, ctype, dist=ALL_DIST, arch=ALL_ARCH):
        self.versions = versions
        self.ctype = ctype
        if not dist:
            dist = ALL_DIST
        if not arch:
            arch = ALL_ARCH
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
        return Component(self.versions.copy(), self.ctype, self.dist, self.arch)

    def merge(self, versions, overwritten=True):
        for package in versions:
            if overwritten or package not in self.versions:
                self.versions[package] = versions[package]

    def subtract(self, versions):
        for package in versions:
            if package in self.versions and self.versions[package] == versions[package]:
                del self.versions[package]

    def dump(self, config=False, priority=999):
        result = []
        for package in sorted(self.versions.keys(), key=str.casefold):
            if config and self.ctype == 'deb':
                lines = 'Package: {0}\nPin: version {1}\nPin-Priority: {2}\n\n'.format(package, self.versions[package], priority)
                result.append(lines)
            else:
                result.append('{0}=={1}'.format(package, self.versions[package]))
        return "\n".join(result)

    def dump_to_file(self, version_file, config=False, priority=999):
        if len(self.versions) <= 0:
            return
        with open(version_file, 'w') as f:
            f.write(self.dump(config, priority))

    def dump_to_path(self, file_path, config=False, priority=999):
        if len(self.versions) <= 0:
            return
        if not os.path.exists(file_path):
            os.makedirs(file_path)
        filename = self.get_filename()
        if config and self.ctype == 'deb':
            filename = VERSION_DEB_PREFERENCE 
        file_path = os.path.join(file_path, filename)
        self.dump_to_file(file_path, config, priority)

    # Check if the self component can be overwritten by the input component
    def check_overwritable(self, component, for_all_dist=False, for_all_arch=False):
        if self.ctype != component.ctype:
            return False
        if self.dist != component.dist and not (for_all_dist and self.dist == ALL_DIST):
            return False
        if self.arch != component.arch and not (for_all_arch and self.arch == ALL_ARCH):
            return False
        return True

    # Check if the self component can inherit the package versions from the input component
    def check_inheritable(self, component):
        if self.ctype != component.ctype:
            return False
        if self.dist != component.dist and component.dist == ALL_DIST:
            return False
        if self.arch != component.arch and component.arch == ALL_ARCH:
            return False
        return True

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

    def get_order_keys(self):
        dist = self.dist
        if not dist or dist == ALL_DIST:
            dist = ''
        arch = self.arch
        if not arch or arch == ALL_ARCH:
            arch = ''
        return (self.ctype, dist, arch)


class VersionModule:
    '''
    The version module represents a build target, such as docker image, host image, consists of multiple components.

    name   -- The name of the image, such as sonic-slave-buster, docker-lldp, etc
    '''
    def __init__(self, name=None, components=None):
        self.name = name
        self.components = components

    # Overwrite the docker/host image/base image versions
    def overwrite(self, module, for_all_dist=False, for_all_arch=False):
        # Overwrite from generic one to detail one
        # For examples: versions-deb overwrtten by versions-deb-buster, and versions-deb-buster overwritten by versions-deb-buster-amd64
        components = sorted(module.components, key = lambda x : x.get_order_keys())
        not_merged_components = []
        for merge_component in components:
            merged = False
            for component in self.components:
                if component.check_overwritable(merge_component, for_all_dist=for_all_dist, for_all_arch=for_all_arch):
                    component.merge(merge_component.versions, True)
                    merged = True
            if not merged:
                self.components.append(merge_component)


    # Inherit the package versions from the default setting
    def inherit(self, default_module):
        # Inherit from the detail one to the generic one
        # Prefer to inherit versions from versions-deb-buster, better than versions-deb
        components = sorted(default_module.components, key = lambda x : x.get_order_keys(), reverse=True)
        for merge_component in components:
            merged = False
            for component in self.components:
                if component.check_inheritable(merge_component):
                    component.merge(merge_component.versions, False)
                    merged = True
            if not merged:
                self.components.append(merge_component)

    def subtract(self, default_module):
        for component in self.components:
            for default_component in default_module.components:
                if component.ctype != default_component.ctype:
                    continue
                component.subtract(default_component.versions)


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

    def dump(self, module_path, config=False, priority=999):
        version_file_pattern = os.path.join(module_path, VERSION_PREFIX + '*')
        for filename in glob.glob(version_file_pattern):
            os.remove(filename)
        for component in self.components:
            component.dump_to_path(module_path, config, priority)

    def clean_info(self, clean_dist=True, clean_arch=True):
        for component in self.components:
            if clean_dist:
                component.dist = ALL_DIST
            if clean_arch:
                component.arch = ALL_ARCH

    def clone(self):
        components = []
        for component in self.components:
            components.append(component.clone())
        return VersionModule(self.name, components)

    @classmethod
    def get_module_path_by_name(cls, source_path, module_name):
        common_modules = ['host-image', 'host-base-image']
        if module_name in common_modules:
            return os.path.join(source_path, 'files/build/versions', module_name)
        if module_name.startswith('build-sonic-slave-'):
            return os.path.join(source_path, 'files/build/versions/build', module_name)
        return os.path.join(source_path, 'files/build/versions/dockers', module_name)

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

class VersionBuild:
    '''
    The VersionBuild consists of multiple version modules.

    '''
    def __init__(self, target_path="./target", source_path='.'):
        self.target_path = target_path
        self.source_path = source_path
        self.modules = {}

    def load_from_target(self):
        dockers_path = os.path.join(self.target_path, 'versions/dockers')
        build_path = os.path.join(self.target_path, 'versions/build')
        modules = {}
        self.modules = modules
        file_paths = glob.glob(dockers_path + '/*')
        file_paths += glob.glob(build_path + '/build-*')
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

    def load_by_module_name(self, module_name, filter_ctype=None, filter_dist=None, filter_arch=None):
        module_path = self.get_module_path_by_name(module_name)
        module = VersionModule()
        module.load(module_path, filter_ctype=filter_ctype, filter_dist=filter_dist, filter_arch=filter_arch)
        default_module_path = self.get_module_path_by_name(DEFAULT_MODULE)
        default_module = VersionModule()
        default_module.load(default_module_path, filter_ctype=filter_ctype, filter_dist=filter_dist, filter_arch=filter_arch)
        module.inherit(default_module)
        return module
        

    def overwrite(self, build, for_all_dist=False, for_all_arch=False):
        for target_module in build.modules.values():
            module = self.modules.get(target_module.name, None)
            tmp_module = target_module.clone()
            tmp_module.clean_info(for_all_dist, for_all_arch)
            if module:
                module.overwrite(tmp_module, for_all_dist=for_all_dist, for_all_arch=for_all_arch)
            else:
                self.modules[target_module.name] = tmp_module

    def dump(self):
        for module in self.modules.values():
            module_path = self.get_module_path(module)
            module.dump(module_path)

    def subtract(self, default_module):
        for module in self.modules.values():
            if module.name == DEFAULT_MODULE:
                continue
            if module.name == 'host-base-image':
                continue
            module.subtract(default_module)

    def freeze(self, rebuild=False, for_all_dist=False, for_all_arch=False):
        if rebuild:
            self.load_from_target()
            default_module = self.get_default_module()
            self._clean_component_info()
            self.subtract(default_module)
            self.modules[DEFAULT_MODULE] = default_module
            self.dump()
            return
        self.load_from_source()
        default_module = self.modules.get(DEFAULT_MODULE, None)
        target_build = VersionBuild(self.target_path, self.source_path)
        target_build.load_from_target()
        if not default_module:
            raise Exception("The default versions does not exist")
        target_build.subtract(default_module)
        self.overwrite(target_build, for_all_dist=for_all_dist, for_all_arch=for_all_arch)
        self.dump()

    def get_default_module(self):
        if DEFAULT_MODULE in self.modules:
            return self.modules[DEFAULT_MODULE]
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
        return VersionModule(DEFAULT_MODULE, components)

    def get_docker_version_modules(self):
        modules = []
        for module_name in self.modules:
            if module_name.startswith('sonic-slave-'):
                continue
            if module_name == DEFAULT_MODULE:
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
        return self.get_module_path_by_name(module.name)

    def get_module_path_by_name(self, module_name):
        return VersionModule.get_module_path_by_name(self.source_path, module_name)

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
            base_module.overwrite(dbg_module)
        for module_name in dbg_modules:
            del self.modules[module_name]

    def _clean_component_info(self, clean_dist=True, clean_arch=True):
        for module in self.modules.values():
            module.clean_info(clean_dist, clean_arch)

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


class VersionManagerCommands:
    def __init__(self):
        usage = 'version_manager.py <command> [<args>]\n\n'
        usage = usage + 'The most commonly used commands are:\n'
        usage = usage + '   freeze     Freeze the version files\n'
        usage = usage + '   generate   Generate the version files'
        parser = argparse.ArgumentParser(description='Version manager', usage=usage)
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(sys.argv[1:2])
        if not hasattr(self, args.command):
            print('Unrecognized command: {0}'.format(args.command))
            parser.print_help()
            exit(1)
        getattr(self, args.command)()

    def freeze(self):
        parser = argparse.ArgumentParser(description = 'Freeze the version files')
        parser.add_argument('-t', '--target_path', default='./target', help='target path')
        parser.add_argument('-s', '--source_path', default='.', help='source path')

        # store_true which implies default=False
        parser.add_argument('-r', '--rebuild', action='store_true', help='rebuild all versions')
        parser.add_argument('-d', '--for_all_dist', action='store_true', help='apply the versions for all distributions')
        parser.add_argument('-a', '--for_all_arch', action='store_true', help='apply the versions for all architectures')
        args = parser.parse_args(sys.argv[2:])
        build = VersionBuild(target_path=args.target_path, source_path=args.source_path)
        build.freeze(rebuild=args.rebuild, for_all_dist=args.for_all_dist, for_all_arch=args.for_all_arch)

    def merge(self):
        parser = argparse.ArgumentParser(description = 'Merge the version files')
        parser.add_argument('-t', '--target_path', required=True, help='target path to save the merged version files')
        parser.add_argument('-m', '--module_path', default=None, help='merge path, use the target path if not specified')
        parser.add_argument('-b', '--base_path', required=True, help='base path, merge to the module path')
        parser.add_argument('-e', '--exclude_module_path', default=None, help='exclude module path')
        args = parser.parse_args(sys.argv[2:])
        module_path = args.module_path
        if not module_path:
            module_path = args.target_path
        if not os.path.exists(module_path):
            print('The module path {0} does not exist'.format(module_path))
        if not os.path.exists(args.target_path):
            os.makedirs(args.target_path)
        module = VersionModule()
        module.load(module_path)
        base_module = VersionModule()
        base_module.load(args.base_path)
        module.overwrite(base_module)
        if args.exclude_module_path:
            exclude_module = VersionModule()
            exclude_module.load(args.exclude_module_path)
            module.subtract(exclude_module)
        module.dump(args.target_path)

    def generate(self):
        script_path = os.path.dirname(sys.argv[0])
        root_path = os.path.dirname(script_path)
        default_version_path = os.path.join(root_path, DEFAULT_VERSION_PATH)

        parser = argparse.ArgumentParser(description = 'Generate the version files')
        parser.add_argument('-t', '--target_path', required=True, help='target path to generate the version lock files')
        group = parser.add_mutually_exclusive_group(required=True)
        group.add_argument('-m', '--module_path', help="module apth, such as ./dockers/docker-lldp, ./sonic-slave-buster, etc")
        group.add_argument('-n', '--module_name', help="module name, such as docker-lldp, sonic-slave-buster, etc")
        parser.add_argument('-s', '--source_path', default='.', help='source path')
        parser.add_argument('-d', '--distribution', required=True, help="distribution")
        parser.add_argument('-a', '--architecture', required=True, help="architecture")
        parser.add_argument('-p', '--priority', default=999, help="priority of the debian apt preference")

        args = parser.parse_args(sys.argv[2:])
        module_path = args.module_path
        if not module_path:
            module_path = VersionModule.get_module_path_by_name(args.source_path, module_name)
        if not os.path.exists(args.target_path):
            os.makedirs(args.target_path)
        module = VersionModule()
        module.load(module_path, filter_dist=args.distribution, filter_arch=args.architecture)
        default_module_path = VersionModule.get_module_path_by_name(args.source_path, DEFAULT_MODULE)
        default_module = VersionModule()
        default_module.load(default_module_path, filter_dist=args.distribution, filter_arch=args.architecture)
        module.inherit(default_module)
        module.dump(args.target_path, config=True, priority=args.priority)

if __name__ == "__main__":
    VersionManagerCommands()
