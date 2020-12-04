# sfputil.py
#
# Platform-specific SFP transceiver interface for SONiC
#

try:
    import time
    import string
    from ctypes import create_string_buffer
    from sonic_sfp.sfputilbase import SfpUtilBase
except ImportError as e:
    raise ImportError("%s - required module not found" % str(e))


class SfpUtil(SfpUtilBase):
    """Platform-specific SfpUtil class"""

    PORT_START = 1
    PORT_END = 56
    PORTS_IN_BLOCK = 56
    QSFP_PORT_START = 49
    QSFP_PORT_END = 56

    _port_to_eeprom_mapping = {}
    _port_to_i2c_mapping = {
        1: 32,
        2: 33,
        3: 34,
        4: 35,
        5: 36,
        6: 37,
        7: 38,
        8: 39,
        9: 40,
        10: 41,
        11: 42,
        12: 43,
        13: 44,
        14: 45,
        15: 46,
        16: 47,
        17: 48,
        18: 49,
        19: 50,
        20: 51,
        21: 52,
        22: 53,
        23: 54,
        24: 55,
        25: 56,
        26: 57,
        27: 58,
        28: 59,
        29: 60,
        30: 61,
        31: 62,
        32: 63,
        33: 64,
        34: 65,
        35: 66,
        36: 67,
        37: 68,
        38: 69,
        39: 70,
        40: 71,
        41: 72,
        42: 73,
        43: 74,
        44: 75,
        45: 76,
        46: 77,
        47: 78,
        48: 79,
        49: 80,  # QSFP49
        50: 81,  # QSFP50
        51: 82,  # QSFP51
        52: 83,  # QSFP52
        53: 84,  # QSFP53
        54: 85,  # QSFP54
        55: 86,  # QSFP55
        56: 87,  # QSFP56
    }

    @property
    def port_start(self):
        return self.PORT_START

    @property
    def port_end(self):
        return self.PORT_END

    @property
    def qsfp_port_start(self):
        return self.QSFP_PORT_START

    @property
    def qsfp_port_end(self):
        return self.QSFP_PORT_END

    @property
    def qsfp_ports(self):
        return list(range(self.QSFP_PORT_START, self.PORTS_IN_BLOCK + 1))

    @property
    def port_to_eeprom_mapping(self):
        return self._port_to_eeprom_mapping

    def __init__(self):
        eeprom_path = '/sys/bus/i2c/devices/{0}-0050/eeprom'
        for x in range(self.port_start, self.port_end+1):
            self.port_to_eeprom_mapping[x] = eeprom_path.format(self._port_to_i2c_mapping[x])
        SfpUtilBase.__init__(self)

    def get_presence(self, port_num):
        # Check for invalid port_num
        if port_num < self.port_start or port_num > self.port_end:
            return False

        try:
            if port_num < self.qsfp_port_start:
                reg_file = open("/sys/class/cpld-sfp28/port-"+str(port_num)+"/pre_n")
            else:
                reg_file = open("/sys/class/gpio/gpio"+str((port_num-self.qsfp_port_start)*4+34)+"/value")
        except IOError as e:
            print("Error: unable to open file: %s" % str(e))
            return False

        reg_value = reg_file.readline().rstrip()
        if port_num < self.qsfp_port_start:
            if reg_value == '1':
                return True
        else:
            if reg_value == '0':
                return True

        return False

    def get_low_power_mode(self, port_num):
        # Check for invalid port_num
        if port_num < self.qsfp_port_start or port_num > self.qsfp_port_end:
            return False

        try:
            reg_file = open("/sys/class/gpio/gpio"+str((port_num-self.qsfp_port_start)*4+35)+"/value")
        except IOError as e:
            print("Error: unable to open file: %s" % str(e))
            return False

        reg_value = int(reg_file.readline().rstrip())

        if reg_value == 0:
            return False

        return True

    def set_low_power_mode(self, port_num, lpmode):
        # Check for invalid port_num
        if port_num < self.qsfp_port_start or port_num > self.qsfp_port_end:
            return False

        try:
            reg_file = open("/sys/class/gpio/gpio"+str((port_num-self.qsfp_port_start)*4+35)+"/value", "r+")
        except IOError as e:
            print("Error: unable to open file: %s" % str(e))
            return False

        reg_value = int(reg_file.readline().rstrip())

        # LPMode is active high; set or clear the bit accordingly
        if lpmode is True:
            reg_value = 1
        else:
            reg_value = 0

        reg_file.write(hex(reg_value))
        reg_file.close()

        return True

    def reset(self, port_num):
        # Check for invalid port_num
        if port_num < self.qsfp_port_start or port_num > self.port_end:
            return False

        try:
            reg_file = open("/sys/class/gpio/gpio"+str((port_num-self.qsfp_port_start)*4+32)+"/value", "r+")
        except IOError as e:
            print("Error: unable to open file: %s" % str(e))
            return False

        reg_value = 0
        reg_file.write(hex(reg_value))
        reg_file.close()

        # Sleep 2 second to allow it to settle
        time.sleep(2)

        # Flip the value back write back to the register to take port out of reset
        try:
            reg_file = open("/sys/class/gpio/gpio"+str((port_num-self.qsfp_port_start)*4+32)+"/value", "r+")
        except IOError as e:
            print("Error: unable to open file: %s" % str(e))
            return False

        reg_value = 1
        reg_file.write(hex(reg_value))
        reg_file.close()

        return True

    def get_transceiver_change_event(self):
        """
        TODO: This function need to be implemented
        when decide to support monitoring SFP(Xcvrd)
        on this platform.
        """
        raise NotImplementedError
