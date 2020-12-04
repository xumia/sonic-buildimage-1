import json
from swsscommon import swsscommon

import jinja2
import netaddr

from .log import log_warn, log_err, log_info, log_debug, log_crit
from .manager import Manager
from .template import TemplateFabric
from .utils import run_command


class BGPPeerGroupMgr(object):
    """ This class represents peer-group and routing policy for the peer_type """
    def __init__(self, common_objs, base_template):
        """
        Construct the object
        :param common_objs: common objects
        :param base_template: path to the directory with Jinja2 templates
        """
        self.cfg_mgr = common_objs['cfg_mgr']
        self.constants = common_objs['constants']
        tf = common_objs['tf']
        self.policy_template = tf.from_file(base_template + "policies.conf.j2")
        self.peergroup_template = tf.from_file(base_template + "peer-group.conf.j2")

    def update(self, name, **kwargs):
        """
        Update peer-group and routing policy for the peer with the name
        :param name: name of the peer. Used for logging only
        :param kwargs: dictionary with parameters for rendering
        """
        rc_policy = self.update_policy(name, **kwargs)
        rc_pg = self.update_pg(name, **kwargs)
        return rc_policy and rc_pg

    def update_policy(self, name, **kwargs):
        """
        Update routing policy for the peer
        :param name: name of the peer. Used for logging only
        :param kwargs: dictionary with parameters for rendering
        """
        try:
            policy = self.policy_template.render(**kwargs)
        except jinja2.TemplateError as e:
            log_err("Can't render policy template name: '%s': %s" % (name, str(e)))
            return False
        self.update_entity(policy, "Routing policy for peer '%s'" % name)
        return True

    def update_pg(self, name, **kwargs):
        """
        Update peer-group for the peer
        :param name: name of the peer. Used for logging only
        :param kwargs: dictionary with parameters for rendering
        """
        try:
            pg = self.peergroup_template.render(**kwargs)
        except jinja2.TemplateError as e:
            log_err("Can't render peer-group template: '%s': %s" % (name, str(e)))
            return False

        if kwargs['vrf'] == 'default':
            cmd = ('router bgp %s\n' % kwargs['bgp_asn']) + pg
        else:
            cmd = ('router bgp %s vrf %s\n' % (kwargs['bgp_asn'], kwargs['vrf'])) + pg
        self.update_entity(cmd, "Peer-group for peer '%s'" % name)
        return True

    def update_entity(self, cmd, txt):
        """
        Send commands to FRR
        :param cmd: commands to send in a raw form
        :param txt: text for the syslog output
        :return:
        """
        self.cfg_mgr.push(cmd)
        log_info("%s has been scheduled to be updated" % txt)
        return True


class BGPPeerMgrBase(Manager):
    """ Manager of BGP peers """
    def __init__(self, common_objs, db_name, table_name, peer_type, check_neig_meta):
        """
        Initialize the object
        :param common_objs: common objects
        :param table_name: name of the table with peers
        :param peer_type: type of the peers. It is used to find right templates
        """
        self.common_objs = common_objs
        self.constants = self.common_objs["constants"]
        self.fabric = common_objs['tf']
        self.peer_type = peer_type

        base_template = "bgpd/templates/" + self.constants["bgp"]["peers"][peer_type]["template_dir"] + "/"
        self.templates = {
            "add":         self.fabric.from_file(base_template + "instance.conf.j2"),
            "delete":      self.fabric.from_string('no neighbor {{ neighbor_addr }}'),
            "shutdown":    self.fabric.from_string('neighbor {{ neighbor_addr }} shutdown'),
            "no shutdown": self.fabric.from_string('no neighbor {{ neighbor_addr }} shutdown'),
        }

        deps = [
            ("CONFIG_DB", swsscommon.CFG_DEVICE_METADATA_TABLE_NAME, "localhost/bgp_asn"),
            ("CONFIG_DB", swsscommon.CFG_LOOPBACK_INTERFACE_TABLE_NAME, "Loopback0"),
            ("LOCAL", "local_addresses", ""),
            ("LOCAL", "interfaces", ""),
        ]

        if check_neig_meta:
            self.check_neig_meta = 'bgp' in self.constants \
                               and 'use_neighbors_meta' in self.constants['bgp'] \
                               and self.constants['bgp']['use_neighbors_meta']
        else:
            self.check_neig_meta = False

        self.check_deployment_id = 'bgp' in self.constants \
                               and 'use_deployment_id' in self.constants['bgp'] \
                               and self.constants['bgp']['use_deployment_id']

        if self.check_neig_meta:
            deps.append(("CONFIG_DB", swsscommon.CFG_DEVICE_NEIGHBOR_METADATA_TABLE_NAME, ""))

        if self.check_deployment_id:
            deps.append(("CONFIG_DB", swsscommon.CFG_DEVICE_METADATA_TABLE_NAME, "localhost/deployment_id"))

        super(BGPPeerMgrBase, self).__init__(
            common_objs,
            deps,
            db_name,
            table_name,
        )

        self.peers = self.load_peers()
        self.peer_group_mgr = BGPPeerGroupMgr(self.common_objs, base_template)
        return

    def set_handler(self, key, data):
        """
         It runs on 'SET' command
        :param key: key of the changed table
        :param data: the data associated with the change
        """
        vrf, nbr = self.split_key(key)
        peer_key = (vrf, nbr)
        if peer_key not in self.peers:
            return self.add_peer(vrf, nbr, data)
        else:
            return self.update_peer(vrf, nbr, data)

    def add_peer(self, vrf, nbr, data):
        """
        Add a peer into FRR. This is used if the peer is not existed in FRR yet
        :param vrf: vrf name. Name is equal "default" for the global vrf
        :param nbr: neighbor ip address (name for dynamic peer type)
        :param data: associated data
        :return: True if this adding was successful, False otherwise
        """
        print_data = vrf, nbr, data
        bgp_asn = self.directory.get_slot("CONFIG_DB", swsscommon.CFG_DEVICE_METADATA_TABLE_NAME)["localhost"]["bgp_asn"]
        #
        lo0_ipv4 = self.get_lo0_ipv4()
        if lo0_ipv4 is None:
            log_warn("Loopback0 ipv4 address is not presented yet")
            return False
        #
        if "local_addr" not in data:
            log_warn("Peer %s. Missing attribute 'local_addr'" % nbr)
        else:
            # The bgp session that belongs to a vnet cannot be advertised as the default BGP session.
            # So we need to check whether this bgp session belongs to a vnet.
            data["local_addr"] = str(netaddr.IPNetwork(str(data["local_addr"])).ip)
            interface = self.get_local_interface(data["local_addr"])
            if not interface:
                print_data = nbr, data["local_addr"]
                log_debug("Peer '%s' with local address '%s' wait for the corresponding interface to be set" % print_data)
                return False
            vnet = self.get_vnet(interface)
            if vnet:
                # Ignore the bgp session that is in a vnet
                log_info("Ignore the BGP peer '%s' as the interface '%s' is in vnet '%s'" % (nbr, interface, vnet))
                return True

        kwargs = {
            'CONFIG_DB__DEVICE_METADATA': self.directory.get_slot("CONFIG_DB", swsscommon.CFG_DEVICE_METADATA_TABLE_NAME),
            'CONFIG_DB__BGP_BBR': self.directory.get_slot('CONFIG_DB', 'BGP_BBR'),
            'constants': self.constants,
            'bgp_asn': bgp_asn,
            'vrf': vrf,
            'neighbor_addr': nbr,
            'bgp_session': data,
            'loopback0_ipv4': lo0_ipv4,
        }
        if self.check_neig_meta:
            neigmeta = self.directory.get_slot("CONFIG_DB", swsscommon.CFG_DEVICE_NEIGHBOR_METADATA_TABLE_NAME)
            if 'name' in data and data["name"] not in neigmeta:
                log_info("DEVICE_NEIGHBOR_METADATA is not ready for neighbor '%s' - '%s'" % (nbr, data['name']))
                return False
            kwargs['CONFIG_DB__DEVICE_NEIGHBOR_METADATA'] = neigmeta

        tag = data['name'] if 'name' in data else nbr
        self.peer_group_mgr.update(tag, **kwargs)

        try:
            cmd = self.templates["add"].render(**kwargs)
        except jinja2.TemplateError as e:
            msg = "Peer '(%s|%s)'. Error in rendering the template for 'SET' command '%s'" % print_data
            log_err("%s: %s" % (msg, str(e)))
            return True
        if cmd is not None:
            self.apply_op(cmd, vrf)
            key = (vrf, nbr)
            self.peers.add(key)
            log_info("Peer '(%s|%s)' has been scheduled to be added with attributes '%s'" % print_data)

        return True

    def update_peer(self, vrf, nbr, data):
        """
        Update a peer. This is used when the peer is already in the FRR
        Update support only "admin_status" for now
        :param vrf: vrf name. Name is equal "default" for the global vrf
        :param nbr: neighbor ip address (name for dynamic peer type)
        :param data: associated data
        :return: True if this adding was successful, False otherwise
        """
        if "admin_status" in data:
            self.change_admin_status(vrf, nbr, data)
        else:
            log_err("Peer '(%s|%s)': Can't update the peer. Only 'admin_status' attribute is supported" % (vrf, nbr))

        return True

    def change_admin_status(self, vrf, nbr, data):
        """
        Change admin status of a peer
        :param vrf: vrf name. Name is equal "default" for the global vrf
        :param nbr: neighbor ip address (name for dynamic peer type)
        :param data: associated data
        :return: True if this adding was successful, False otherwise
        """
        if data['admin_status'] == 'up':
            self.apply_admin_status(vrf, nbr, "no shutdown", "up")
        elif data['admin_status'] == 'down':
            self.apply_admin_status(vrf, nbr, "shutdown", "down")
        else:
            print_data = vrf, nbr, data['admin_status']
            log_err("Peer '%s|%s': Can't update the peer. It has wrong attribute value attr['admin_status'] = '%s'" % print_data)

    def apply_admin_status(self, vrf, nbr, template_name, admin_state):
        """
        Render admin state template and apply the command to the FRR
        :param vrf: vrf name. Name is equal "default" for the global vrf
        :param nbr: neighbor ip address (name for dynamic peer type)
        :param template_name: name of the template to render
        :param admin_state: desired admin state
        :return: True if this adding was successful, False otherwise
        """
        print_data = vrf, nbr, admin_state
        ret_code = self.apply_op(self.templates[template_name].render(neighbor_addr=nbr), vrf)
        if ret_code:
            log_info("Peer '%s|%s' admin state is set to '%s'" % print_data)
        else:
            log_err("Can't set peer '%s|%s' admin state to '%s'." % print_data)

    def del_handler(self, key):
        """
        'DEL' handler for the BGP PEER tables
        :param key: key of the neighbor
        """
        vrf, nbr = self.split_key(key)
        peer_key = (vrf, nbr)
        if peer_key not in self.peers:
            log_warn("Peer '(%s|%s)' has not been found" % (vrf, nbr))
            return
        cmd = self.templates["delete"].render(neighbor_addr=nbr)
        ret_code = self.apply_op(cmd, vrf)
        if ret_code:
            log_info("Peer '(%s|%s)' has been removed" % (vrf, nbr))
            self.peers.remove(peer_key)
        else:
            log_err("Peer '(%s|%s)' hasn't been removed" % (vrf, nbr))

    def apply_op(self, cmd, vrf):
        """
        Push commands cmd into FRR
        :param cmd: commands in raw format
        :param vrf: vrf where the commands should be applied
        :return: True if no errors, False if there are errors
        """
        bgp_asn = self.directory.get_slot("CONFIG_DB", swsscommon.CFG_DEVICE_METADATA_TABLE_NAME)["localhost"]["bgp_asn"]
        if vrf == 'default':
            cmd = ('router bgp %s\n' % bgp_asn) + cmd
        else:
            cmd = ('router bgp %s vrf %s\n' % (bgp_asn, vrf)) + cmd
        self.cfg_mgr.push(cmd)
        return True

    def get_lo0_ipv4(self):
        """
        Extract Loopback0 ipv4 address from the Directory
        :return: ipv4 address for Loopback0, None if nothing found
        """
        loopback0_ipv4 = None
        for loopback in self.directory.get_slot("CONFIG_DB", swsscommon.CFG_LOOPBACK_INTERFACE_TABLE_NAME).keys():
            if loopback.startswith("Loopback0|"):
                loopback0_prefix_str = loopback.replace("Loopback0|", "")
                loopback0_ip_str = loopback0_prefix_str[:loopback0_prefix_str.find('/')]
                if TemplateFabric.is_ipv4(loopback0_ip_str):
                    loopback0_ipv4 = loopback0_ip_str
                    break

        return loopback0_ipv4

    def get_local_interface(self, local_addr):
        """
        Get interface according to the local address from the directory
        :param: directory: Directory object that stored metadata of interfaces
        :param: local_addr: Local address of the interface
        :return: Return the metadata of the interface with the local address
                 If the interface has not been set, return None
        """
        local_addresses = self.directory.get_slot("LOCAL", "local_addresses")
        # Check if the local address of this bgp session has been set
        if local_addr not in local_addresses:
            return None
        local_address = local_addresses[local_addr]
        interfaces = self.directory.get_slot("LOCAL", "interfaces")
        # Check if the information for the interface of this local address has been set
        if "interface" in local_address and local_address["interface"] in interfaces:
            return interfaces[local_address["interface"]]
        else:
            return None

    @staticmethod
    def get_vnet(interface):
        """
        Get the VNet name of the interface
        :param: interface: The metadata of the interface
        :return: Return the vnet name of the interface if this interface belongs to a vnet,
                 Otherwise return None
        """
        if "vnet_name" in interface and interface["vnet_name"]:
            return interface["vnet_name"]
        else:
            return None

    @staticmethod
    def split_key(key):
        """
        Split key into ip address and vrf name. If there is no vrf, "default" would be return for vrf
        :param key: key to split
        :return: vrf name extracted from the key, peer ip address extracted from the key
        """
        if '|' not in key:
            return 'default', key
        else:
            return tuple(key.split('|', 1))

    @staticmethod
    def load_peers():
        """
        Load peers from FRR.
        :return: set of peers, which are already installed in FRR
        """
        command = ["vtysh", "-c", "show bgp vrfs json"]
        ret_code, out, err = run_command(command)
        if ret_code == 0:
            js_vrf = json.loads(out)
            vrfs = js_vrf['vrfs'].keys()
        else:
            log_crit("Can't read bgp vrfs: %s" % err)
            raise Exception("Can't read bgp vrfs: %s" % err)
        peers = set()
        for vrf in vrfs:
            command = ["vtysh", "-c", 'show bgp vrf %s neighbors json' % str(vrf)]
            ret_code, out, err = run_command(command)
            if ret_code == 0:
                js_bgp = json.loads(out)
                for nbr in js_bgp.keys():
                    peers.add((vrf, nbr))
            else:
                log_crit("Can't read vrf '%s' neighbors: %s" % (vrf, str(err)))
                raise Exception("Can't read vrf '%s' neighbors: %s" % (vrf, str(err)))

        return peers