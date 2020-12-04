#
# psuutil.py
# Platform-specific PSU status interface for SONiC
#


import os.path
import logging
import sys

if sys.version_info[0] < 3:
    import commands
else:
    import subprocess as commands


S5232F_MAX_PSUS = 2
IPMI_PSU1_DATA = "docker exec -it pmon ipmitool raw 0x04 0x2d 0x31 |  awk '{print substr($0,9,1)}'"
IPMI_PSU1_DATA_DOCKER = "ipmitool raw 0x04 0x2d 0x31 |  awk '{print substr($0,9,1)}'"
IPMI_PSU2_DATA = "docker exec -it pmon ipmitool raw 0x04 0x2d 0x32 |  awk '{print substr($0,9,1)}'"
IPMI_PSU2_DATA_DOCKER = "ipmitool raw 0x04 0x2d 0x32 |  awk '{print substr($0,9,1)}'"
PSU_PRESENCE = "PSU{0}_stat"
# Use this for older firmware
# PSU_PRESENCE="PSU{0}_prsnt"


try:
    from sonic_psu.psu_base import PsuBase
except ImportError as e:
    raise ImportError(str(e) + "- required module not found")


class PsuUtil(PsuBase):
    """Platform-specific PSUutil class"""

    def __init__(self):
        PsuBase.__init__(self)

    def isDockerEnv(self):
        num_docker = open('/proc/self/cgroup', 'r').read().count(":/docker")
        if num_docker > 0:
            return True
        else:
            return False

    # Fetch a BMC register
    def get_pmc_register(self, reg_name):

        status = 1
        ipmi_cmd_1 = IPMI_PSU1_DATA
        ipmi_cmd_2 = IPMI_PSU1_DATA
        dockerenv = self.isDockerEnv()
        if dockerenv == True:
            if index == 1:
                status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU1_DATA_DOCKER)
            elif index == 2:
                status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU2_DATA_DOCKER)
        else:
            if index == 1:
                status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU1_DATA)
            elif index == 2:
                status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU2_DATA)

        if status:
            logging.error('Failed to execute ipmitool')
            sys.exit(0)

        output = ipmi_sdr_list

        return output

    def get_num_psus(self):
        """
        Retrieves the number of PSUs available on the device
        :return: An integer, the number of PSUs available on the device
         """
        S5232F_MAX_PSUS = 2
        return S5232F_MAX_PSUS

    def get_psu_status(self, index):
        """
        Retrieves the oprational status of power supply unit (PSU) defined
                by index <index>
        :param index: An integer, index of the PSU of which to query status
        :return: Boolean, True if PSU is operating properly, False if PSU is\
        faulty
        """
        # Until psu_status is implemented this is hardcoded temporarily

        psu_status = 'f'
        ret_status = 1
        dockerenv = self.isDockerEnv()
        if dockerenv == True:
            if index == 1:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU1_DATA_DOCKER)
            elif index == 2:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU2_DATA_DOCKER)
        else:
            if index == 1:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU1_DATA)
            elif index == 2:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU2_DATA)

        if ret_status:
            logging.error('Failed to execute ipmitool : ')
            sys.exit(0)

        psu_status = ipmi_sdr_list
        return (not int(psu_status, 16) > 1)

    def get_psu_presence(self, index):
        """
        Retrieves the presence status of power supply unit (PSU) defined
                by index <index>
        :param index: An integer, index of the PSU of which to query status
        :return: Boolean, True if PSU is plugged, False if not
        """
        psu_status = '0'
        ret_status = 1
        dockerenv = self.isDockerEnv()
        if dockerenv == True:
            if index == 1:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU1_DATA_DOCKER)
            elif index == 2:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU2_DATA_DOCKER)
        else:
            if index == 1:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU1_DATA)
            elif index == 2:
                ret_status, ipmi_sdr_list = commands.getstatusoutput(IPMI_PSU2_DATA)

        if ret_status:
            logging.error('Failed to execute ipmitool : ')
            sys.exit(0)

        psu_status = ipmi_sdr_list
        return (int(psu_status, 16) & 1)
