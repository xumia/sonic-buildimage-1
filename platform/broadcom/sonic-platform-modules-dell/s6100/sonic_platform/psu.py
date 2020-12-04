#!/usr/bin/env python

########################################################################
# DellEMC S6100
#
# Module contains an implementation of SONiC Platform Base API and
# provides the PSUs' information which are available in the platform
#
########################################################################


try:
    import os
    from sonic_platform_base.psu_base import PsuBase
    from sonic_platform.fan import Fan
except ImportError as e:
    raise ImportError(str(e) + "- required module not found")


class Psu(PsuBase):
    """DellEMC Platform-specific PSU class"""

    HWMON_DIR = "/sys/devices/platform/SMF.512/hwmon/"
    HWMON_NODE = os.listdir(HWMON_DIR)[0]
    MAILBOX_DIR = HWMON_DIR + HWMON_NODE

    def __init__(self, psu_index):
        PsuBase.__init__(self)
        # PSU is 1-based in DellEMC platforms
        self.index = psu_index + 1
        self.psu_presence_reg = "psu{}_presence".format(self.index)
        self.psu_serialno_reg = "psu{}_serialno".format(self.index)
        if self.index == 1:
            self.psu_voltage_reg = "in30_input"
            self.psu_current_reg = "curr602_input"
            self.psu_power_reg = "power2_input"
        elif self.index == 2:
            self.psu_voltage_reg = "in32_input"
            self.psu_current_reg = "curr702_input"
            self.psu_power_reg = "power4_input"

        # Passing True to specify it is a PSU fan
        psu_fan = Fan(fan_index=self.index, psu_fan=True)
        self._fan_list.append(psu_fan)

    def _get_pmc_register(self, reg_name):
        # On successful read, returns the value read from given
        # reg_name and on failure returns 'ERR'
        rv = 'ERR'
        mb_reg_file = self.MAILBOX_DIR + '/' + reg_name

        if (not os.path.isfile(mb_reg_file)):
            return rv

        try:
            with open(mb_reg_file, 'r') as fd:
                rv = fd.read()
        except Exception as error:
            rv = 'ERR'

        rv = rv.rstrip('\r\n')
        rv = rv.lstrip(" ")
        return rv

    def get_name(self):
        """
        Retrieves the name of the device

        Returns:
            string: The name of the device
        """
        return "PSU{}".format(self.index)

    def get_presence(self):
        """
        Retrieves the presence of the Power Supply Unit (PSU)

        Returns:
            bool: True if PSU is present, False if not
        """
        status = False
        psu_presence = self._get_pmc_register(self.psu_presence_reg)
        if (psu_presence != 'ERR'):
            psu_presence = int(psu_presence, 16)
            # Checking whether bit 0 is not set
            if (~psu_presence & 0b1):
                status = True

        return status

    def get_model(self):
        """
        Retrieves the part number of the PSU

        Returns:
            string: Part number of PSU
        """
        # For Serial number "US-01234D-54321-25A-0123-A00", the part
        # number is "01234D"
        psu_serialno = self._get_pmc_register(self.psu_serialno_reg)
        if (psu_serialno != 'ERR') and self.get_presence():
            if (len(psu_serialno.split('-')) > 1):
                psu_partno = psu_serialno.split('-')[1]
            else:
                psu_partno = 'NA'
        else:
            psu_partno = 'NA'

        return psu_partno

    def get_serial(self):
        """
        Retrieves the serial number of the PSU

        Returns:
            string: Serial number of PSU
        """
        # Sample Serial number format "US-01234D-54321-25A-0123-A00"
        psu_serialno = self._get_pmc_register(self.psu_serialno_reg)
        if (psu_serialno == 'ERR') or not self.get_presence():
            psu_serialno = 'NA'

        return psu_serialno

    def get_status(self):
        """
        Retrieves the operational status of the PSU

        Returns:
            bool: True if PSU is operating properly, False if not
        """
        status = False
        psu_status = self._get_pmc_register(self.psu_presence_reg)
        if (psu_status != 'ERR'):
            psu_status = int(psu_status, 16)
            # Checking whether both bit 3 and bit 2 are not set
            if (~psu_status & 0b1000) and (~psu_status & 0b0100):
                status = True

        return status

    def get_voltage(self):
        """
        Retrieves current PSU voltage output

        Returns:
            A float number, the output voltage in volts,
            e.g. 12.1
        """
        psu_voltage = self._get_pmc_register(self.psu_voltage_reg)
        if (psu_voltage != 'ERR') and self.get_presence():
            # Converting the value returned by driver which is in
            # millivolts to volts
            psu_voltage = float(psu_voltage) / 1000
        else:
            psu_voltage = 0.0

        return psu_voltage

    def get_current(self):
        """
        Retrieves present electric current supplied by PSU

        Returns:
            A float number, electric current in amperes,
            e.g. 15.4
        """
        psu_current = self._get_pmc_register(self.psu_current_reg)
        if (psu_current != 'ERR') and self.get_presence():
            # Converting the value returned by driver which is in
            # milliamperes to amperes
            psu_current = float(psu_current) / 1000
        else:
            psu_current = 0.0

        return psu_current

    def get_power(self):
        """
        Retrieves current energy supplied by PSU

        Returns:
            A float number, the power in watts,
            e.g. 302.6
        """
        psu_power = self._get_pmc_register(self.psu_power_reg)
        if (psu_power != 'ERR') and self.get_presence():
            # Converting the value returned by driver which is in
            # microwatts to watts
            psu_power = float(psu_power) / 1000000
        else:
            psu_power = 0.0

        return psu_power

    def get_powergood_status(self):
        """
        Retrieves the powergood status of PSU

        Returns:
            A boolean, True if PSU has stablized its output voltages and
            passed all its internal self-tests, False if not.
        """
        status = False
        if self.get_status() and self._fan_list[0].get_status():
            status = True

        return status

    def get_status_led(self):
        """
        Gets the state of the PSU status LED

        Returns:
            A string, one of the predefined STATUS_LED_COLOR_* strings.
        """
        if self.get_powergood_status():
            return self.STATUS_LED_COLOR_GREEN
        else:
            return self.STATUS_LED_COLOR_OFF

    def set_status_led(self, color):
        """
        Sets the state of the PSU status LED
        Args:
            color: A string representing the color with which to set the
                   PSU status LED
        Returns:
            bool: True if status LED state is set successfully, False if
                  not
        """
        # In S6100, SmartFusion FPGA controls the PSU LED and the PSU
        # LED state cannot be changed from CPU.
        return False
