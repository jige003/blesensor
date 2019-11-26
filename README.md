## blesensor
> mac系统基于cc2540 usb dongle的蓝牙协议抓包传感器工具

## 用法
```
usage: blesensor [ -f /tmp/ble.pcap ] | [ -c 37 ] | [ -p ] | [ -v ] | [ -h ]
	 -f pcap filename path
	 -c ble sniffe channel number
	 -p use fifo pipe mode; default path: /tmp/ble; wireshark command: wireshark -i /tmp/ble
	 -v show verbose
	 -h help
```
