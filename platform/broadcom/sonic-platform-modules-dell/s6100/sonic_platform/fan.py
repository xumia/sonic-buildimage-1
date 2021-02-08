#!/usr/bin/env python

########################################################################
# DellEMC S6100
#
# Module contains an implementation of SONiC Platform Base API and
# provides the Fans' information which are available in the platform.
#
########################################################################

import os.path

try:
    from sonic_platform_base.fan_base import FanBase
except ImportError as e:
    raise ImportError(str(e) + "- required module not found")

MAX_S6100_PSU_FAN_SPEED = 18000
MAX_S6100_FAN_SPEED = 16000


class Fan(FanBase):
    """DellEMC Platform-specific Fan class"""

    HWMON_DIR = "/sys/devices/platform/SMF.512/hwmon/"
    HWMON_NODE = os.listdir(HWMON_DIR)[0]
    MAILBOX_DIR = HWMON_DIR + HWMON_NODE

    def __init__(self, fantray_index=1, psu_index=1, psu_fan=False, dependency=None):
        self.is_psu_fan = psu_fan
        if not self.is_psu_fan:
            self.fantrayindex = fantray_index
            self.dependency = dependency
            self.fan_status_reg = "fan{}_alarm".format(
                        2 * self.fantrayindex - 1)
            self.get_fan_speed_reg = "fan{}_input".format(
                        2 * self.fantrayindex - 1)
            self.get_fan_dir_reg = "fan{}_airflow".format(
                        2 * self.fantrayindex - 1)
            self.max_fan_speed = MAX_S6100_FAN_SPEED
        else:
            self.psuindex = psu_index
            self.fan_presence_reg = "fan{}_fault".format(self.psuindex + 10)
            self.get_fan_speed_reg = "fan{}_input".format(self.psuindex + 10)
            self.get_fan_dir_reg = "fan{}_airflow".format(self.psuindex + 10)
            self.max_fan_speed = MAX_S6100_PSU_FAN_SPEED

    def _get_pmc_register(self, reg_name):
        # On successful read, returns the value read from given
        # reg_name and on failure returns 'ERR'
        rv = 'ERR'
        mb_reg_file = self.MAILBOX_DIR+'/'+reg_name

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
        Retrieves the fan name
        Returns:
            string: The name of the device
        """
        if not self.is_psu_fan:
            return "FanTray{}-Fan1".format(self.fantrayindex)
        else:
            return "PSU{} Fan".format(self.psuindex)

    def get_model(self):
        """
        Retrieves the part number of the FAN
        Returns:
            string: Part number of FAN
        """
        return 'NA'

    def get_serial(self):
        """
        Retrieves the serial number of the FAN
        Returns:
            string: Serial number of FAN
        """
        return 'NA'

    def get_presence(self):
        """
        Retrieves the presence of the FAN
        Returns:
            bool: True if fan is present, False if not
        """
        if not self.is_psu_fan:
            return self.dependency.get_presence()

        presence = False
        fan_presence = self._get_pmc_register(self.fan_presence_reg)
        if (fan_presence != 'ERR'):
            fan_presence = int(fan_presence, 10)
            if (~fan_presence & 0b1):
                presence = True

        return presence

    def get_status(self):
        """
        Retrieves the operational status of the FAN
        Returns:
            bool: True if FAN is operating properly, False if not
        """
        status = False
        if self.is_psu_fan:
            fantray_status = self._get_pmc_register(self.get_fan_speed_reg)
            if (fantray_status != 'ERR'):
                fantray_status = int(fantray_status, 10)
                if (fantray_status > 1000):
                    status = True
        else:
            fantray_status = self._get_pmc_register(self.fan_status_reg)
            if (fantray_status != 'ERR'):
                fantray_status = int(fantray_status, 10)
                if (~fantray_status & 0b1):
                    status = True

        return status

    def get_position_in_parent(self):
        """
        Retrieves 1-based relative physical position in parent device.
        Returns:
            integer: The 1-based relative physical position in parent
            device or -1 if cannot determine the position
        """
        return 1

    def is_replaceable(self):
        """
        Indicate whether Fan is replaceable.
        Returns:
            bool: True if it is replaceable.
        """
        return False

    def get_direction(self):
        """
        Retrieves the fan airflow direction
        Returns:
            A string, either FAN_DIRECTION_INTAKE or FAN_DIRECTION_EXHAUST
            depending on fan direction

        Notes:
            In DellEMC platforms,
            - Forward/Exhaust : Air flows from Port side to Fan side.
            - Reverse/Intake  : Air flows from Fan side to Port side.
        """
        direction = [self.FAN_DIRECTION_INTAKE, self.FAN_DIRECTION_EXHAUST]
        fan_direction = self._get_pmc_register(self.get_fan_dir_reg)
        if (fan_direction != 'ERR') and self.get_presence():
            fan_direction = int(fan_direction, 10)
        else:
            return self.FAN_DIRECTION_NOT_APPLICABLE
        return direction[fan_direction]

    def get_speed(self):
        """
        Retrieves the speed of fan
        Returns:
            int: percentage of the max fan speed
        """
        fan_speed = self._get_pmc_register(self.get_fan_speed_reg)
        if (fan_speed != 'ERR') and self.get_presence():
            speed_in_rpm = int(fan_speed, 10)
            speed = (100 * speed_in_rpm)//self.max_fan_speed
        else:
            speed = 0

        return speed

    def get_speed_tolerance(self):
        """
        Retrieves the speed tolerance of the fan
        Returns:
            An integer, the percentage of variance from target speed which is
        considered tolerable
        """
        if self.get_presence():
            # The tolerance value is fixed as 20% for all the DellEmc platform
            tolerance = 20
        else:
            tolerance = 0

        return tolerance

    def set_speed(self, speed):
        """
        Set fan speed to expected value
        Args:
            speed: An integer, the percentage of full fan speed to set fan to,
                   in the range 0 (off) to 100 (full speed)
        Returns:
            bool: True if set success, False if fail.
        """
        # Fan speeds are controlled by Smart-fussion FPGA.
        return False

    def set_status_led(self, color):
        """
        Set led to expected color
        Args:
            color: A string representing the color with which to set the
                   fan module status LED
        Returns:
            bool: True if set success, False if fail.
        """
        # No LED available for FanTray and PSU Fan
        # Return True to avoid thermalctld alarm.
        return True

    def get_status_led(self):
        """
        Gets the state of the Fan status LED

        Returns:
            A string, one of the predefined STATUS_LED_COLOR_* strings.
        """
        # No LED available for FanTray and PSU Fan
        return None

    def get_target_speed(self):
        """
        Retrieves the target (expected) speed of the fan
        Returns:
            An integer, the percentage of full fan speed, in the range 0 (off)
                 to 100 (full speed)
        """
        # Fan speeds are controlled by Smart-fussion FPGA.
        # Return current speed to avoid false thermalctld alarm.
        return self.get_speed()
