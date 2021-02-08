from unittest.mock import MagicMock, patch

import os
from bgpcfgd.directory import Directory
from bgpcfgd.template import TemplateFabric
from . import swsscommon_test
from .util import load_constants
from swsscommon import swsscommon
import bgpcfgd.managers_bgp

TEMPLATE_PATH = os.path.abspath('../../dockers/docker-fpm-frr/frr')

def constructor():
    cfg_mgr = MagicMock()
    constants = load_constants()['constants']
    common_objs = {
        'directory': Directory(),
        'cfg_mgr':   cfg_mgr,
        'tf':        TemplateFabric(TEMPLATE_PATH),
        'constants': constants
    }

    return_value_map = {
        "['vtysh', '-c', 'show bgp vrfs json']": (0, "{\"vrfs\": {\"default\": {}}}", ""),
        "['vtysh', '-c', 'show bgp vrf default neighbors json']": (0, "{\"10.10.10.1\": {}, \"20.20.20.1\": {}, \"fc00:10::1\": {}}", "")
    }

    bgpcfgd.managers_bgp.run_command = lambda cmd: return_value_map[str(cmd)]
    m = bgpcfgd.managers_bgp.BGPPeerMgrBase(common_objs, "CONFIG_DB", swsscommon.CFG_BGP_NEIGHBOR_TABLE_NAME, "general", True)
    assert m.peer_type == "general"
    assert m.check_neig_meta == ('bgp' in constants and 'use_neighbors_meta' in constants['bgp'] and constants['bgp']['use_neighbors_meta'])

    m.directory.put("CONFIG_DB", swsscommon.CFG_DEVICE_METADATA_TABLE_NAME, "localhost", {"bgp_asn": "65100"})
    m.directory.put("CONFIG_DB", swsscommon.CFG_LOOPBACK_INTERFACE_TABLE_NAME, "Loopback0|11.11.11.11/32", {})
    m.directory.put("CONFIG_DB", swsscommon.CFG_LOOPBACK_INTERFACE_TABLE_NAME, "Loopback0|FC00:1::32/128", {})
    m.directory.put("LOCAL", "local_addresses", "30.30.30.30", {"interface": "Ethernet4|30.30.30.30/24"})
    m.directory.put("LOCAL", "local_addresses", "fc00:20::20", {"interface": "Ethernet8|fc00:20::20/96"})
    m.directory.put("LOCAL", "interfaces", "Ethernet4|30.30.30.30/24", {"anything": "anything"})
    m.directory.put("LOCAL", "interfaces", "Ethernet8|fc00:20::20/96", {"anything": "anything"})

    return m

@patch('bgpcfgd.managers_bgp.log_info')
def test_update_peer_up(mocked_log_info): 
    m = constructor()
    res = m.set_handler("10.10.10.1", {"admin_status": "up"})
    assert res, "Expect True return value for peer update"
    mocked_log_info.assert_called_with("Peer 'default|10.10.10.1' admin state is set to 'up'")

@patch('bgpcfgd.managers_bgp.log_info')
def test_update_peer_up_ipv6(mocked_log_info): 
    m = constructor()
    res = m.set_handler("fc00:10::1", {"admin_status": "up"})
    assert res, "Expect True return value for peer update"
    mocked_log_info.assert_called_with("Peer 'default|fc00:10::1' admin state is set to 'up'")

@patch('bgpcfgd.managers_bgp.log_info')
def test_update_peer_down(mocked_log_info): 
    m = constructor()
    res = m.set_handler("10.10.10.1", {"admin_status": "down"})
    assert res, "Expect True return value for peer update"
    mocked_log_info.assert_called_with("Peer 'default|10.10.10.1' admin state is set to 'down'")

@patch('bgpcfgd.managers_bgp.log_err')
def test_update_peer_no_admin_status(mocked_log_err):
    m = constructor()
    res = m.set_handler("10.10.10.1", {"anything": "anything"})
    assert res, "Expect True return value for peer update"
    mocked_log_err.assert_called_with("Peer '(default|10.10.10.1)': Can't update the peer. Only 'admin_status' attribute is supported")

@patch('bgpcfgd.managers_bgp.log_err')
def test_update_peer_invalid_admin_status(mocked_log_err):
    m = constructor()
    res = m.set_handler("10.10.10.1", {"admin_status": "invalid"})
    assert res, "Expect True return value for peer update"
    mocked_log_err.assert_called_with("Peer 'default|10.10.10.1': Can't update the peer. It has wrong attribute value attr['admin_status'] = 'invalid'")

def test_add_peer():
    m = constructor()
    res = m.set_handler("30.30.30.1", {"local_addr": "30.30.30.30", "admin_status": "up"})
    assert res, "Expect True return value"

def test_add_peer_ipv6():
    m = constructor()
    res = m.set_handler("fc00:20::1", {"local_addr": "fc00:20::20", "admin_status": "up"})
    assert res, "Expect True return value"

@patch('bgpcfgd.managers_bgp.log_warn')
def test_add_peer_no_local_addr(mocked_log_warn):
    m = constructor()
    res = m.set_handler("30.30.30.1", {"admin_status": "up"})
    assert res, "Expect True return value"
    mocked_log_warn.assert_called_with("Peer 30.30.30.1. Missing attribute 'local_addr'")

@patch('bgpcfgd.managers_bgp.log_debug')
def test_add_peer_invalid_local_addr(mocked_log_debug):
    m = constructor()
    res = m.set_handler("30.30.30.1", {"local_addr": "40.40.40.40", "admin_status": "up"})
    assert not res, "Expect False return value"
    mocked_log_debug.assert_called_with("Peer '30.30.30.1' with local address '40.40.40.40' wait for the corresponding interface to be set")

@patch('bgpcfgd.managers_bgp.log_info')
def test_del_handler(mocked_log_info):
    m = constructor()
    m.del_handler("10.10.10.1")
    mocked_log_info.assert_called_with("Peer '(default|10.10.10.1)' has been removed")

@patch('bgpcfgd.managers_bgp.log_warn')
def test_del_handler_nonexist_peer(mocked_log_warn):
    m = constructor()
    m.del_handler("40.40.40.1")
    mocked_log_warn.assert_called_with("Peer '(default|40.40.40.1)' has not been found")
