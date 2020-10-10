#!/usr/bin/python

import glob
import os
import re

VERSIONS_PATH="target/versions"

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

def get_changed_versions(init_version_file, final_version_file):
    init_versions = get_versions(init_version_file)
    final_versions = get_versions(final_version_file)
    result = {}
    for package in final_versions:
        final_version = final_versions[package]
        init_version = init_versions.get(package, None)
        if not init_version or init_version != final_version:
            result[package] = final_version
    return result


def get_all_changed_versions(version_file_name):
    result = {}
    for file in glob.glob('./target/versions/*/*/{}'.format(version_file_name)):
        parent_path = os.path.dirname(file)
        module = os.path.basename(parent_path)
        distro = os.path.basename(os.path.dirname(parent_path))
        distro_result = result.get(distro, None)
        if not distro_result:
            distro_result = {}
            result[distro] = distro_result
        init_version_file = os.path.join(parent_path, 'init-versions', version_file_name)
        versions =  get_changed_versions(init_version_file, file)
        distro_result[module] = versions
    return result

def version_part_compare(version_part1, version_part2):
    if len(version_part1) != len(version_part2):
        return len(version_part1) - len(version_part2)
    if version_part1 > version_part2:
        return 1
    return -1

def version_compare(version1, version2):
    if version1 == version2:
        return 0
    regex = "[:\.\+\-]+"
    parts1 = re.split(regex, version1)
    parts2 = re.split(regex, version2)
    for i in range(0, min(len(parts1), len(parts2))):
        compare_result = version_part_compare(parts1[i], parts2[i])
        if compare_result != 0:
            return compare_result
    return len(parts1) - len(parts2)  
 

def get_preference_versions(versions):
    result={}
    build_versions = {}
    image_versions = {}
    default_versions = {}
    result['default'] = default_versions
    for distro in versions:
        distro_versions = versions[distro]
        for module in distro_versions:
            module_versions = distro_versions[module]
            target_versions = image_versions
            if module == 'build-packages':
                target_versions = build_versions
            for package in module_versions:
                version = module_versions[package]
                existing_versions = target_versions.get(package, None)
                if not existing_versions:
                    existing_versions = {}
                    target_versions[package] = existing_versions
                existing_modules = existing_versions.get(version, [])
                existing_versions[version] = existing_modules
                existing_modules.append(module)
    # Generate versions for default module
    for package in image_versions:
        package_versions= image_versions[package]
        build_package_versions = build_versions.get(package, {})
        max_refer_version = None
        max_refer_count = 0
        max_refer_module = None
        for version in package_versions:
            if version in build_package_versions:
                continue
            refer_count = len(package_versions[version])
            if refer_count > max_refer_count or (refer_count == max_refer_count and version_compare(version, max_refer_version) > 0):
                max_refer_count = refer_count
                max_refer_version = version
                max_refer_module = package_versions[version][0]
        if max_refer_count > 1 or (max_refer_version is not None and '-slave-' not in max_refer_module):
            default_versions[package] = max_refer_version
    # Generate versions for all modules
    for distro in versions:
        distro_versions = versions[distro]
        for module in distro_versions:
            module_versions = distro_versions[module]
            if module == 'build-packages':
                continue
            module_result = result.get(module, None)
            if not module_result:
                module_result = {}
                result[module] = module_result
            for package in module_versions:
                version = module_versions[package]
                default_version = default_versions.get(package, None)
                if version != default_version:
                    module_result[package] = version
    return result

def generate_versions_file(module, version_file_name, versions):
    file_path = os.path.join('dockers', module, version_file_name)
    if module == 'default':
        file_path = os.path.join('files/build/versions', version_file_name)
    elif '-slave-' in module:
        file_path = os.path.join(module, version_file_name)
    if os.path.exists(file_path):
        os.remove(file_path)
    if len(versions) == 0:
        return
    with open(file_path, 'w') as fp:
        for package in sorted(versions.keys(), key=lambda s: s.lower()):
            fp.write('{0}=={1}\n'.format(package, versions[package]))

def generate_versions_deb():
    versions = get_all_changed_versions("versions-deb")
    for distro in versions:
        temp_versions = {}
        temp_versions[distro] = versions[distro]
        module_versions = get_preference_versions(temp_versions)
        for module in module_versions:
            if module.endswith('-dbg'):
                continue
            version_file_name = 'versions-deb'
            if module == 'default':
                version_file_name = 'versions-deb-{0}'.format(distro)
            module_dbg = module + '-dbg'
            if module_dbg in module_versions:
                prefer_versions =  module_versions[module_dbg]
            else:
                prefer_versions = module_versions[module]
            generate_versions_file(module, version_file_name, prefer_versions)
           

def generate_versions_pip(version_file_name):
    versions = get_all_changed_versions(version_file_name)
    module_versions = get_preference_versions(versions)
    for module in module_versions:
        if module.endswith('-dbg'):
            continue
        module_dbg = module + '-dbg'
        if module_dbg in module_versions:
            prefer_versions =  module_versions[module_dbg]
        else:
            prefer_versions = module_versions[module]
        generate_versions_file(module, version_file_name, prefer_versions)

generate_versions_pip("versions-py2")
generate_versions_pip("versions-py3")
generate_versions_deb()
